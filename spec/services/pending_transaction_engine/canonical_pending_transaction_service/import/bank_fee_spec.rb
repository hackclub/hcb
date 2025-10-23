# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::Import::BankFee do

  context "when there is a raw pending bank fee transaction ready for processing" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingBankFeeTransaction.count).to eq(0) # there are no previously processed raw pending bank fee transactions

      create(:raw_pending_bank_fee_transaction, date_posted: Date.current)
      # TODO: there is a not null on CanonicalPendingTransaction#date, but not on RawPendingBankFeeTransaction#date_posted,
      # should we propagate the not null there so we never run into this?

      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when there are previously processed raw pending bank fee transactions" do
    before do
      raw_pending_bank_fee_transaction = create(:raw_pending_bank_fee_transaction)
      _processed_bank_fee_canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_bank_fee_transaction:)
    end

    it "ignores it when processing" do
      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end

    context "when there are also ready to process raw pending bank fee transactions" do
      it "processes into a CanonicalPendingTransaction" do
        new_bank_fee_transaction = create(:raw_pending_bank_fee_transaction, date_posted: Date.current)
        expect(RawPendingBankFeeTransaction.count).to eq(2) # there is a processed and non processed bank fee transaction

        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.raw_pending_bank_fee_transaction_id).to eq(new_bank_fee_transaction.id)
      end
    end
  end

  context "fronted" do
    let(:raw_pending_bank_fee_transaction) {
      create(:raw_pending_bank_fee_transaction,
             date_posted: Date.current,
             amount_cents:)
    }

    before do
      raw_pending_bank_fee_transaction
    end

    context "when amount_cents is positive" do
      let(:amount_cents) { 100 }

      it "fronted is true" do
        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.amount_cents).to eq(amount_cents)
        expect(pending_transaction).to be_fronted
      end
    end

    context "when amount_cents is not-positive" do
      let(:amount_cents) { 0 }

      it "fronted is false" do
        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.amount_cents).to eq(amount_cents)
        expect(pending_transaction).to_not be_fronted
      end
    end
  end
end
