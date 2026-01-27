# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement::Incoming, type: :model do
  let(:disbursement) { create(:disbursement) }
  let(:incoming) { described_class.new(disbursement) }

  describe "#hcb_code" do
    it "returns the incoming HCB code" do
      expect(incoming.hcb_code).to eq(disbursement.incoming_hcb_code)
    end

    it "uses the 550 code prefix" do
      expect(incoming.hcb_code).to eq("HCB-550-#{disbursement.id}")
    end
  end

  describe "#event" do
    it "returns the destination event" do
      expect(incoming.event).to eq(disbursement.destination_event)
    end
  end

  describe "#signed_amount" do
    it "returns a positive amount" do
      expect(incoming.signed_amount).to be_positive
    end

    it "returns the absolute value of the disbursement amount" do
      expect(incoming.signed_amount).to eq(disbursement.amount.abs)
    end
  end

  describe "#subledger" do
    it "returns the destination subledger" do
      expect(incoming.subledger).to eq(disbursement.destination_subledger)
    end

    context "when destination subledger is set" do
      let(:destination_event) { create(:event) }
      let(:destination_subledger) { create(:subledger, event: destination_event) }
      let(:disbursement_with_subledger) { create(:disbursement, event: destination_event, destination_subledger:) }
      let(:incoming_with_subledger) { described_class.new(disbursement_with_subledger) }

      it "returns the destination subledger" do
        expect(incoming_with_subledger.subledger).to eq(destination_subledger)
      end
    end
  end

  describe "#transaction_category" do
    it "returns the destination transaction category" do
      expect(incoming.transaction_category).to eq(disbursement.destination_transaction_category)
    end
  end

  describe "#local_hcb_code" do
    it "returns an HcbCode record" do
      expect(incoming.local_hcb_code).to be_a(HcbCode)
    end

    it "returns an HcbCode with the incoming hcb_code" do
      expect(incoming.local_hcb_code.hcb_code).to eq(incoming.hcb_code)
    end
  end

  describe "#canonical_transactions" do
    it "queries by the incoming hcb_code" do
      ct = create(:canonical_transaction)
      ct.update_column(:hcb_code, incoming.hcb_code)

      expect(incoming.canonical_transactions).to include(ct)
    end

    it "does not include transactions with the outgoing hcb_code" do
      ct = create(:canonical_transaction)
      ct.update_column(:hcb_code, disbursement.outgoing_hcb_code)

      incoming.instance_variable_set(:@canonical_transactions, nil)
      expect(incoming.canonical_transactions).not_to include(ct)
    end
  end

  describe "delegation" do
    it "delegates fulfilled? to disbursement" do
      expect(incoming.fulfilled?).to eq(disbursement.fulfilled?)
    end

    it "delegates state to disbursement" do
      expect(incoming.state).to eq(disbursement.state)
    end

    it "delegates id to disbursement" do
      expect(incoming.id).to eq(disbursement.id)
    end
  end
end
