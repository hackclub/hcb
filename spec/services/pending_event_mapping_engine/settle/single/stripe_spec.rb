# frozen_string_literal: true

require "rails_helper"

describe PendingEventMappingEngine::Settle::Single::Stripe do
  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
  let(:authorization_id) { "iauth_settle_single" }
  let(:amount_cents) { -1000 }

  # The authorization, as the issuing webhook imports it.
  def import_authorization!
    raw = create(:raw_pending_stripe_transaction, amount_cents:, date_posted: Date.current, stripe_transaction_id: authorization_id)
    raw.update!(stripe_transaction: raw.stripe_transaction.merge("card" => { "id" => stripe_card.stripe_id }))
    cpt = PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe.new(raw_pending_stripe_transaction: raw).run
    PendingEventMappingEngine::Map::Single::Stripe.new(canonical_pending_transaction: cpt).run
    cpt.reload
  end

  # The capture, as TransactionEngine::CanonicalTransactionService::Import imports it.
  def import_capture!
    raw = create(:raw_stripe_transaction, amount_cents:, stripe_authorization_id: authorization_id, stripe_card:, date_posted: Date.current)
    raw.update!(stripe_transaction: raw.stripe_transaction.merge("authorization" => authorization_id))
    hashed = create(:hashed_transaction, raw_stripe_transaction: raw, date: Date.current)

    CanonicalTransaction.create!(
      date: hashed.date,
      memo: raw.memo,
      amount_cents: raw.amount_cents,
      canonical_hashed_mappings: [CanonicalHashedMapping.new(hashed_transaction: hashed)],
      transaction_source: raw
    )
  end

  # Every amount_cents value written to ledger_items while the block runs.
  def ledger_amounts_written(&)
    amounts = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next unless payload[:sql].match?(/(UPDATE|INSERT INTO) "ledger_items"/)

      payload[:binds].to_a.each { |bind| amounts << bind.value if bind.name == "amount_cents" }
    end

    yield

    amounts
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "settles the authorization against the capture" do
    cpt = import_authorization!

    ct = import_capture!

    expect(ct.reload.canonical_pending_transaction).to eq(cpt)
    expect(cpt.reload).to be_settled
  end

  # The ledger item counts every unsettled outgoing CPT plus every CT, so a
  # capture that is visible before its settled mapping doubles the item's
  # amount and the org's balance.
  it "never persists an amount that counts both the authorization and the capture" do
    cpt = import_authorization!
    ledger_item = cpt.ledger_item

    amounts = ledger_amounts_written { import_capture! }

    expect(amounts).not_to include(amount_cents * 2)
    expect(ledger_item.reload.amount_cents).to eq(amount_cents)
    expect(ledger_item.status).to eq("settled")
    expect(event.ledger.balance_cents).to eq(amount_cents)
  end

  it "creates the settled mapping in the same transaction as the capture" do
    import_authorization!
    allow(CanonicalPendingSettledMapping).to receive(:create!).and_raise(ActiveRecord::StatementInvalid.new("settle failed"))
    already_imported = CanonicalTransaction.count

    expect { import_capture! }.to raise_error(ActiveRecord::StatementInvalid)
    expect(CanonicalTransaction.count).to eq(already_imported)
  end

  context "when the capture arrives before the authorization has been imported" do
    it "leaves the capture unsettled for the nightly sweep" do
      ct = import_capture!
      expect(ct.reload.canonical_pending_settled_mapping).to be_nil

      cpt = import_authorization!
      PendingEventMappingEngine::Settle::Stripe.new.run

      expect(ct.reload.canonical_pending_transaction).to eq(cpt)
      expect(ct.ledger_item.reload.amount_cents).to eq(amount_cents)
    end
  end
end
