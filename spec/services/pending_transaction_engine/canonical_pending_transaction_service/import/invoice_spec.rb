# frozen_string_literal: true

require "rails_helper"

describe PendingTransactionEngine::CanonicalPendingTransactionService::Import::Invoice do

  context "when there is a pending invoice transaction ready for processing" do
    it "processes into a CanonicalPendingTransaction" do
      expect(RawPendingInvoiceTransaction.count).to eq(0)


      raw_pending_invoice_transaction = create(:raw_pending_invoice_transaction, date_posted: Date.current)

      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(1)
    end
  end

  context "when there are previously processed raw pending invoice transactions" do
    let(:raw_pending_invoice_transaction) { create(:raw_pending_invoice_transaction) }

    before do
      _processed_invoice_canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_invoice_transaction:)
    end

    it "ignores it when processing" do
      expect do
        described_class.new.run
      end.to change { CanonicalPendingTransaction.count }.by(0)
    end

    context "when there are also ready to process raw pending invoice transactions" do
      it "processes into a CanonicalPendingTransaction" do
        new_invoice_transaction = create(:raw_pending_invoice_transaction, date_posted: Date.current)
        expect(RawPendingInvoiceTransaction.count).to eq(2)

        expect do
          described_class.new.run
        end.to change { CanonicalPendingTransaction.count }.by(1)

        pending_transaction = CanonicalPendingTransaction.last
        expect(pending_transaction.raw_pending_invoice_transaction_id).to eq(new_invoice_transaction.id)
      end
    end
  end
end
