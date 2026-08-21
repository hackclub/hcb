# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionGroupingEngine::Calculate::HcbCode do
  subject(:run) { described_class.new(canonical_transaction_or_canonical_pending_transaction: ct_or_cp).run }

  describe "unknown transactions" do
    context "when the transaction has never been assigned an hcb_code" do
      let(:ct_or_cp) { build_stubbed(:canonical_transaction, hcb_code: nil) }

      it "computes a fresh unknown code" do
        expect(run).to eq("HCB-000-canonical_transaction_#{ct_or_cp.id}")
      end
    end

    context "when the transaction already has a legacy unknown code" do
      let(:ct_or_cp) { build_stubbed(:canonical_transaction, hcb_code: "HCB-000-#{id}") }
      let(:id) { 42 }

      before { allow(ct_or_cp).to receive(:id).and_return(id) }

      it "does not change it" do
        # Regression test: `run` gets re-invoked periodically (see
        # TransactionGroupingEngine::NightlyJob) for any transaction still
        # classified as unknown. Recomputing MUST return the exact stored
        # string, or the caller will find-or-create a brand new HcbCode row
        # and silently reassign the transaction away from its real
        # ledger_item/comments/receipts/tags.
        expect(run).to eq("HCB-000-42")
      end
    end

    context "when the transaction already has a post-fix unknown code" do
      let(:ct_or_cp) { build_stubbed(:canonical_transaction, hcb_code: "HCB-000-canonical_transaction_42") }

      before { allow(ct_or_cp).to receive(:id).and_return(42) }

      it "does not change it" do
        expect(run).to eq("HCB-000-canonical_transaction_42")
      end
    end

    context "when a CanonicalTransaction and CanonicalPendingTransaction share the same id" do
      it "computes distinct codes for each" do
        ct = build_stubbed(:canonical_transaction, hcb_code: nil)
        cpt = build_stubbed(:canonical_pending_transaction, hcb_code: nil)
        allow(cpt).to receive(:id).and_return(ct.id)

        ct_code = described_class.new(canonical_transaction_or_canonical_pending_transaction: ct).run
        cpt_code = described_class.new(canonical_transaction_or_canonical_pending_transaction: cpt).run

        expect(ct_code).not_to eq(cpt_code)
      end
    end
  end
end
