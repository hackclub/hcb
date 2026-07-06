# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardCharge backfill tasks" do
  it "links pre-existing raw transactions into a single charge" do
    rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_backfill")
    rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_backfill")

    # simulate records that predate the CardCharge model
    CardCharge.delete_all

    Maintenance::BackfillPendingCardChargesTask.new.process(rpst.reload)
    Maintenance::BackfillSettledCardChargesTask.new.process(rst.reload)

    charge = rpst.reload.card_charge
    expect(charge).to be_present
    expect(charge.raw_stripe_transactions).to contain_exactly(rst)
  end

  it "skips records that already have a charge" do
    rpst = create(:raw_pending_stripe_transaction)
    rst = create(:raw_stripe_transaction, stripe_authorization_id: nil)

    expect(Maintenance::BackfillPendingCardChargesTask.new.collection).not_to include(rpst)
    expect(Maintenance::BackfillSettledCardChargesTask.new.collection).not_to include(rst)
  end

  describe Maintenance::BackfillCardChargeLedgerItemsTask do
    it "links the ledger item via the pending transaction's canonical pending transaction" do
      rpst = create(:raw_pending_stripe_transaction)
      ledger_item = create(:ledger_item)
      create(:canonical_pending_transaction, raw_pending_stripe_transaction: rpst, ledger_item:)

      charge = rpst.card_charge
      described_class.new.process(charge)

      expect(ledger_item.reload.linked_object).to eq(charge)
      expect(charge.reload.ledger_item).to eq(ledger_item)
    end

    it "links the ledger item via a settled transaction's canonical transaction" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: nil)
      ledger_item = create(:ledger_item)
      create(:canonical_transaction, transaction_source: rst, ledger_item:)

      charge = rst.card_charge
      described_class.new.process(charge)

      expect(ledger_item.reload.linked_object).to eq(charge)
    end

    it "leaves charges without a ledger item untouched" do
      rpst = create(:raw_pending_stripe_transaction)
      charge = rpst.card_charge

      expect { described_class.new.process(charge) }.not_to raise_error
      expect(charge.reload.ledger_item).to be_nil
    end

    it "does not clobber a ledger item already linked to another object" do
      rpst = create(:raw_pending_stripe_transaction)
      other_linked_object = create(:raw_pending_stripe_transaction).card_charge
      ledger_item = create(:ledger_item, linked_object: other_linked_object)
      create(:canonical_pending_transaction, raw_pending_stripe_transaction: rpst, ledger_item:)

      charge = rpst.card_charge
      expect(Rails.error).to receive(:report).with(instance_of(described_class::AnomalyError))
      described_class.new.process(charge)

      expect(ledger_item.reload.linked_object).to eq(other_linked_object)
    end

    it "skips charges that already have a ledger item" do
      rpst = create(:raw_pending_stripe_transaction)
      charge = rpst.card_charge
      create(:ledger_item, linked_object: charge)

      expect(described_class.new.collection).not_to include(charge)
    end
  end
end
