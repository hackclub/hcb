# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionEngine::CanonicalTransactionService::Import::All do
  let(:event) { create(:event, :with_positive_balance) }

  # Records the ledger item's amount after every refresh so the spec can assert
  # the item never passed through a double-counted state (settled transaction
  # plus still-unsettled pending transaction).
  def record_ledger_amounts(ledger_item)
    amounts = []
    allow_any_instance_of(Ledger::Item).to receive(:refresh!).and_wrap_original do |m, *args|
      m.call(*args).tap { amounts << m.receiver.amount_cents if m.receiver.id == ledger_item.id }
    end
    amounts
  end

  shared_examples "settles in the same database transaction" do
    it "creates the canonical transaction and settles the pending transaction together" do
      expect(cpt).to be_unsettled
      ledger_item = cpt.ledger_item
      expect(ledger_item.amount_cents).to eq(cpt.amount_cents)
      amounts = record_ledger_amounts(ledger_item)

      expect { described_class.new.run }.to change(CanonicalTransaction, :count).by(1)
                                        .and change(CanonicalPendingSettledMapping, :count).by(1)

      ct = hashed_transaction.reload.canonical_transaction
      expect(ct.hcb_code).to eq(cpt.hcb_code)
      expect(ct.canonical_pending_transaction).to eq(cpt)
      expect(ct.ledger_item).to eq(ledger_item)
      expect(cpt.reload).to be_settled

      expect(ledger_item.reload.amount_cents).to eq(cpt.amount_cents)
      expect(amounts).not_to be_empty
      expect(amounts).to all(eq(cpt.amount_cents))
    end

    it "rolls the canonical transaction back when settling fails" do
      allow_any_instance_of(CanonicalPendingTransactionService::Settle).to receive(:run!).and_raise("settle failed")

      expect { described_class.new.run }.to raise_error("settle failed")

      expect(hashed_transaction.reload.canonical_transaction).to be_nil
      expect(HashedTransaction.uncanonized).to include(hashed_transaction)
      expect(cpt.reload).to be_unsettled
    end
  end

  describe "a transaction whose memo carries the pending transaction's HCB short code" do
    let!(:check) do
      IncreaseCheck.create!(
        event:,
        amount: 10_00,
        memo: "Venue deposit",
        payment_for: "Venue deposit",
        recipient_name: "Recipient",
        recipient_email: "recipient@example.com",
        address_line1: "1 Main St",
        address_city: "City",
        address_state: "CA",
        address_zip: "94000"
      )
    end
    let(:cpt) { check.canonical_pending_transaction }
    let!(:hashed_transaction) do
      raw = create(:raw_plaid_transaction, amount_cents: -10_00, plaid_transaction: { "name" => "HCB-#{check.local_hcb_code.short_code} Check" })
      create(:hashed_transaction, raw_plaid_transaction: raw)
    end

    include_examples "settles in the same database transaction"
  end

  describe "a Stripe card transaction" do
    let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
    let!(:raw_pending_stripe_transaction) do
      create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_settle_spec", amount_cents: -5_00)
    end
    let!(:cpt) do
      create(:canonical_pending_transaction, raw_pending_stripe_transaction:, event:, amount_cents: -5_00, memo: "merchant 1")
    end
    let!(:hashed_transaction) do
      raw = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_settle_spec", amount_cents: -5_00, stripe_card:)
      create(:hashed_transaction, raw_stripe_transaction: raw)
    end

    include_examples "settles in the same database transaction"
  end

  it "leaves a transaction without a pending counterpart unsettled" do
    raw = create(:raw_plaid_transaction, amount_cents: 1_00, plaid_transaction: { "name" => "DEPOSIT" })
    create(:hashed_transaction, raw_plaid_transaction: raw)

    expect { described_class.new.run }.to change(CanonicalTransaction, :count).by(1)
                                      .and change(CanonicalPendingSettledMapping, :count).by(0)
  end
end
