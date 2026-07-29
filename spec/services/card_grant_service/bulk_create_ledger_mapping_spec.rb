# frozen_string_literal: true

require "rails_helper"

# Reproduction for the bulk-CSV card-grant / new-ledger orphaning bug.
#
# What the real data (prod card grant #43157) showed:
#   * Each disbursement leg's Ledger::Item exists and is linked FROM its HcbCode,
#     but the leg's CPT/CT have ledger_item_id = NULL, so the item has no
#     transactions, no linked_object, and no primary_ledger (unmapped, pending).
#   * The item was created at SETTLEMENT, not at grant creation — the creation-
#     time item-creation callback never ran.
#   * No `canonical`-related errors were logged.
#
# Root cause: the new-ledger mapping runs in `after_commit` hooks
# (canonical_pending_transaction.rb:176, canonical_transaction.rb:488 — both
# `safely`-wrapped). `CardGrantService::BulkCreate` wraps EVERY row in ONE shared
# `ActiveRecord::Base.transaction` (bulk_create.rb:170), so on commit ~all the
# batch's `after_commit` callbacks fire in a single burst. In Rails 8.1's
# `commit_records` (activerecord .../abstract/transaction.rb) the records are
# walked with `while records.shift` and NO per-record rescue — so the first
# callback that raises aborts the loop and every remaining record's callbacks are
# SKIPPED. The raiser is an un-`safely` I/O callback that fires in the same commit
# (e.g. CardGrant#send_email's deliver_later, or a Turbo broadcast) — a transient
# failure there ("sometimes") skips the ledger-mapping callbacks of every record
# queued after it, leaving those legs orphaned. The CPT/CT blocks are victims,
# not the raiser, which is why nothing `canonical` is logged.
#
# The single-grant path (controller / API v4) is immune because each grant is its
# own transaction: the callback fan-out is tiny and a transient failure in one
# grant can't skip another grant's mapping.
#
# These examples run NON-transactionally so real commits fire the `after_commit`
# callbacks (under transactional fixtures they never run). Cleanup is manual.
RSpec.describe "Card grant bulk creation -> new ledger mapping", type: :model do
  self.use_transactional_tests = false

  after do
    conn = ActiveRecord::Base.connection
    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.execute("TRUNCATE #{tables.map { |t| conn.quote_table_name(t) }.join(", ")} RESTART IDENTITY CASCADE")
  end

  let(:event) { create(:event, :with_positive_balance) }
  let(:sent_by) { create(:user) }

  before do
    create(:organizer_position, :manager, event:, user: sent_by)
    create(:card_grant_setting, event:)
  end

  GRANT_COUNT = 3

  def grant_attrs(index)
    { email: "grant-#{index}@example.com", amount_cents: 1_000, sent_by: }
  end

  # For each leg (outgoing -> HCB-500 -> event ledger; incoming -> HCB-550 ->
  # card-grant ledger): the CPT must be linked to a Ledger::Item and that item
  # must be mapped to the correct primary ledger. Distinguishes "orphaned" (no
  # linked item / NULL ledger_item_id) from "mis-mapped" (wrong ledger).
  def expect_correct_ledger_mapping(card_grant)
    card_grant.reload
    disbursement = card_grant.disbursement

    expected_event_ledger = Ledger.find_by(primary: true, event_id: card_grant.event_id)
    expected_grant_ledger = Ledger.find_by(primary: true, card_grant_id: card_grant.id)

    out_cpt = CanonicalPendingTransaction.find_by(hcb_code: disbursement&.outgoing_hcb_code)
    in_cpt  = CanonicalPendingTransaction.find_by(hcb_code: disbursement&.incoming_hcb_code)

    out_item = out_cpt&.ledger_item&.reload
    in_item  = in_cpt&.ledger_item&.reload

    label = card_grant.email

    aggregate_failures "ledger mapping for #{label}" do
      expect(disbursement).to be_present, "#{label}: card grant has no disbursement"
      expect(out_cpt).to be_present, "#{label}: outgoing leg (HCB-500) CPT is missing"
      expect(in_cpt).to be_present,  "#{label}: incoming leg (HCB-550) CPT is missing"

      # Not orphaned: the CPT is linked to a Ledger::Item.
      expect(out_cpt&.ledger_item_id).to be_present, "#{label}: outgoing CPT ##{out_cpt&.id} has NULL ledger_item_id (orphaned)"
      expect(in_cpt&.ledger_item_id).to be_present,  "#{label}: incoming CPT ##{in_cpt&.id} has NULL ledger_item_id (orphaned)"

      # Mapped to the correct primary ledger.
      expect(out_item&.primary_ledger).to eq(expected_event_ledger),
        "#{label}: outgoing leg mapped to #{out_item&.primary_ledger.inspect}, expected the event's ledger #{expected_event_ledger.inspect}"
      expect(in_item&.primary_ledger).to eq(expected_grant_ledger),
        "#{label}: incoming leg mapped to #{in_item&.primary_ledger.inspect}, expected the card grant's ledger #{expected_grant_ledger.inspect}"
    end
  end

  def create_one_at_a_time
    (1..GRANT_COUNT).map do |i|
      begin
        event.card_grants.create!(**grant_attrs(i))
      rescue
        # A post-commit callback (send_email) may raise AFTER the row committed;
        # the grant is still persisted, so re-fetch it.
        event.card_grants.find_by!(email: grant_attrs(i)[:email])
      end
    end
  end

  def create_in_one_shared_transaction
    ActiveRecord::Base.transaction { create_one_at_a_time }
  rescue
    # A callback raised during the batch commit and propagated out of the
    # transaction; the batch already committed, so return the persisted grants.
    (1..GRANT_COUNT).map { |i| event.card_grants.find_by!(email: grant_attrs(i)[:email]) }
  end

  # ---- Baseline: no callback failures. Both paths already pass (confirmed). ----
  describe "baseline (no callback failures)" do
    it "maps every grant correctly, one at a time" do
      create_one_at_a_time.each { |g| expect_correct_ledger_mapping(g) }
    end

    it "maps every grant correctly in one shared transaction" do
      create_in_one_shared_transaction.each { |g| expect_correct_ledger_mapping(g) }
    end
  end

  # ---- The bug: a transient failure in an un-`safely` post-commit callback. ----
  # We force grant #1's send_email (an after_create_commit that does I/O) to raise
  # once, simulating a real transient mail-queue / Turbo-broadcast hiccup during
  # the commit-callback burst. Because grant #1's CardGrant row commits before its
  # own CPTs and before every later grant, this raise (in the shared transaction)
  # aborts the whole remaining callback chain.
  describe "when a post-commit callback raises transiently during the batch" do
    before do
      allow_any_instance_of(CardGrant).to receive(:send_email) do |cg|
        raise "simulated transient after_commit failure (mail/broadcast)" if cg.email == "grant-1@example.com"
      end
    end

    # EXPECTED PASS: per-grant transactions isolate the blast radius to grant #1;
    # grants #2..N still map correctly.
    context "creating grants one at a time (single-grant path)" do
      it "still maps every later grant correctly" do
        grants = create_one_at_a_time
        grants.drop(1).each { |g| expect_correct_ledger_mapping(g) }
      end
    end

    # EXPECTED FAIL: one shared transaction means grant #1's raise skips the
    # after_commit callbacks of grants #2..N too, leaving their legs orphaned
    # (CPT.ledger_item_id NULL, items unmapped) — exactly the prod symptom.
    context "creating grants in one shared transaction (bulk CSV path)" do
      it "leaves later grants correctly mapped" do
        grants = create_in_one_shared_transaction
        grants.drop(1).each { |g| expect_correct_ledger_mapping(g) }
      end
    end
  end
end
