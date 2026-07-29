# frozen_string_literal: true

require "rails_helper"

# Investigation harness for the card-grant / new-ledger mapping bug.
#
# Hypothesis: the ONLY behavioral difference between creating card grants one at
# a time (the controller + API v4 paths) and creating them via the bulk CSV
# upload is that `CardGrantService::BulkCreate` wraps every `card_grant.save!` in
# a single shared `ActiveRecord::Base.transaction`
# (see app/services/card_grant_service/bulk_create.rb:170).
#
# The NEW ledger mapping runs entirely in `after_commit` / `after_create_commit`
# hooks (CanonicalPendingTransaction -> create Ledger::Item + `map!`; see
# app/models/canonical_pending_transaction.rb:176-189 and
# app/models/ledger/item.rb:89-93). The OLD engine maps synchronously, in the
# same transaction as the disbursement (app/services/disbursement_service/create.rb:67,79),
# which is why the old engine is unaffected by batching.
#
# When each grant is its own transaction, its two legs map (outgoing -> event
# ledger, incoming -> card-grant ledger) in isolation right after that grant
# commits. When all grants share ONE transaction, every leg's commit hook is
# deferred and fires in a single burst when the batch commits — and each hook is
# wrapped in `safely` (canonical_pending_transaction.rb:177), so anything that
# goes wrong there is swallowed, leaving a leg orphaned or mis-mapped.
#
# IMPORTANT: this suite runs NON-transactionally. Under the default
# `use_transactional_fixtures = true`, the wrapping test transaction never
# commits, so `after_commit` callbacks never fire and NO mapping happens in
# either path — which would make both paths "fail" for the wrong reason and
# would not mirror production. Disabling transactional tests here makes commits
# (and their callbacks) real, exactly as in production. We truncate manually in
# an `after` hook to make up for the lost rollback-based cleanup.
RSpec.describe "Card grant creation -> new ledger mapping", type: :model do
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

  # Mirrors the controller / API v4 single-grant path: `build` + `save!`, each in
  # its own implicit transaction.
  def create_one_at_a_time
    (1..GRANT_COUNT).map { |i| event.card_grants.create!(**grant_attrs(i)) }
  end

  # Asserts the end-state a correctly-mapped card grant disbursement must have:
  #   * both legs exist as CPTs (outgoing HCB-500, incoming HCB-550)
  #   * each leg has a Ledger::Item (not orphaned)
  #   * outgoing leg's Ledger::Item primary ledger == the source event's ledger
  #   * incoming leg's Ledger::Item primary ledger == the card grant's ledger
  #
  # `aggregate_failures` so a single grant reports every problem at once, and the
  # messages distinguish "orphaned" (no item) from "mis-mapped" (wrong ledger).
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
      expect(expected_event_ledger).to be_present, "#{label}: event has no primary ledger"
      expect(expected_grant_ledger).to be_present, "#{label}: card grant has no primary ledger"

      expect(out_cpt).to be_present, "#{label}: outgoing leg (HCB-500) CPT is missing"
      expect(in_cpt).to be_present,  "#{label}: incoming leg (HCB-550) CPT is missing"

      # Not orphaned
      expect(out_item).to be_present, "#{label}: outgoing leg has NO Ledger::Item (orphaned)"
      expect(in_item).to be_present,  "#{label}: incoming leg has NO Ledger::Item (orphaned)"

      # Mapped to the correct primary ledger
      expect(out_item&.primary_ledger).to eq(expected_event_ledger),
        "#{label}: outgoing leg mapped to #{out_item&.primary_ledger.inspect}, expected the event's ledger #{expected_event_ledger.inspect}"
      expect(in_item&.primary_ledger).to eq(expected_grant_ledger),
        "#{label}: incoming leg mapped to #{in_item&.primary_ledger.inspect}, expected the card grant's ledger #{expected_grant_ledger.inspect}"
    end
  end

  # EXPECTED TO PASS — mirrors production single-grant behavior (one txn per grant).
  describe "creating card grants one at a time" do
    it "maps both legs of every grant's disbursement to the correct ledger" do
      grants = create_one_at_a_time

      grants.each { |grant| expect_correct_ledger_mapping(grant) }
    end
  end

  # EXPECTED TO FAIL — isolates the single variable under test: identical
  # per-grant create code as above, but wrapped in ONE shared transaction (the
  # thing BulkCreate does). If this fails while the above passes, the shared
  # transaction is the cause.
  describe "creating card grants all at once in one shared DB transaction" do
    it "maps both legs of every grant's disbursement to the correct ledger" do
      grants = ActiveRecord::Base.transaction do
        create_one_at_a_time
      end

      grants.each { |grant| expect_correct_ledger_mapping(grant) }
    end
  end

  # EXPECTED TO FAIL — exercises the real production bulk path end to end.
  describe "creating card grants via CardGrantService::BulkCreate (real bulk path)" do
    it "maps both legs of every grant's disbursement to the correct ledger" do
      csv_content = +"email,amount_cents\n"
      (1..GRANT_COUNT).each { |i| csv_content << "grant-#{i}@example.com,1000\n" }

      result = CardGrantService::BulkCreate.new(
        event:,
        csv_file: StringIO.new(csv_content),
        sent_by:
      ).run

      expect(result.success?).to be(true), "bulk create failed: #{result.errors.inspect}"

      result.card_grants.each { |grant| expect_correct_ledger_mapping(grant) }
    end
  end
end
