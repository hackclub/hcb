# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement::Incoming, type: :model do
  let(:disbursement) { create(:disbursement) }
  let(:incoming) { described_class.new(disbursement) }

  describe "#initialize" do
    it "accepts a Disbursement" do
      expect(incoming.disbursement).to eq(disbursement)
    end

    it "raises ArgumentError for non-Disbursement" do
      expect { described_class.new("not a disbursement") }.to raise_error(ArgumentError, "Expected Disbursement")
    end
  end

  describe "#hcb_code / #local_hcb_code" do
    it "returns the incoming HCB code" do
      expect(incoming.hcb_code).to eq(disbursement.incoming_hcb_code)
    end

    it "is recognized as an incoming disbursement" do
      expect(incoming.local_hcb_code).to be_incoming_disbursement
    end

    it "returns an HcbCode record" do
      expect(incoming.local_hcb_code).to be_a(HcbCode)
    end

    it "returns an HcbCode with the incoming hcb_code" do
      expect(incoming.local_hcb_code.hcb_code).to eq(incoming.hcb_code)
    end
  end

  describe "#event" do
    it "returns the destination event" do
      expect(incoming.event).to eq(disbursement.destination_event)
    end
  end

  describe "#amount" do
    it "returns the absolute value of the disbursement amount" do
      expect(incoming.amount).to eq(disbursement.amount.abs)
    end
  end

  describe "#subledger" do
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

  describe "#canonical_transactions" do
    it "queries by the incoming hcb_code" do
      ct = create(:canonical_transaction)
      ct.update_column(:hcb_code, incoming.hcb_code)

      expect(incoming.canonical_transactions).to include(ct)
    end

    it "does not include transactions with the outgoing hcb_code" do
      ct = create(:canonical_transaction)
      ct.update_column(:hcb_code, disbursement.outgoing_hcb_code)

      expect(incoming.canonical_transactions).not_to include(ct)
    end
  end

  describe "delegation" do
    it "delegates id to disbursement" do
      expect(incoming.id).to eq(disbursement.id)
    end

    it "delegates name to disbursement" do
      expect(incoming.name).to eq(disbursement.name)
    end

    it "delegates source_event to disbursement" do
      expect(incoming.source_event).to eq(disbursement.source_event)
    end

    it "delegates destination_event to disbursement" do
      expect(incoming.destination_event).to eq(disbursement.destination_event)
    end

    it "delegates fulfilled? to disbursement" do
      expect(incoming.fulfilled?).to eq(disbursement.fulfilled?)
    end

    it "delegates reviewing? to disbursement" do
      expect(incoming.reviewing?).to eq(disbursement.reviewing?)
    end

    it "delegates state to disbursement" do
      expect(incoming.state).to eq(disbursement.state)
    end
  end
end
