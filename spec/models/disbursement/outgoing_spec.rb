# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement::Outgoing, type: :model do
  let(:disbursement) { create(:disbursement) }
  let(:outgoing) { described_class.new(disbursement) }

  describe "#initialize" do
    it "accepts a Disbursement" do
      expect(outgoing.disbursement).to eq(disbursement)
    end

    it "raises ArgumentError for non-Disbursement" do
      expect { described_class.new("not a disbursement") }.to raise_error(ArgumentError, "Expected Disbursement")
    end
  end

  describe "#hcb_code / #local_hcb_code" do
    it "returns the outgoing HCB code" do
      expect(outgoing.hcb_code).to eq(disbursement.outgoing_hcb_code)
    end

    it "is recognized as an outgoing disbursement" do
      expect(outgoing.local_hcb_code).to be_outgoing_disbursement
    end

    it "returns an HcbCode record" do
      expect(outgoing.local_hcb_code).to be_a(HcbCode)
    end

    it "returns an HcbCode with the outgoing hcb_code" do
      expect(outgoing.local_hcb_code.hcb_code).to eq(outgoing.hcb_code)
    end
  end

  describe "#event" do
    it "returns the source event" do
      expect(outgoing.event).to eq(disbursement.source_event)
    end
  end

  describe "#amount" do
    it "returns the negative absolute value of the disbursement amount" do
      expect(outgoing.amount).to eq(-disbursement.amount.abs)
    end
  end

  describe "#subledger" do
    context "when source subledger is set" do
      let(:source_event) { create(:event) }
      let(:source_subledger) { create(:subledger, event: source_event) }
      let(:disbursement_with_subledger) { create(:disbursement, source_event:, source_subledger:) }
      let(:outgoing_with_subledger) { described_class.new(disbursement_with_subledger) }

      it "returns the source subledger" do
        expect(outgoing_with_subledger.subledger).to eq(source_subledger)
      end
    end
  end

  describe "#transaction_category" do
    it "returns the source transaction category" do
      expect(outgoing.transaction_category).to eq(disbursement.source_transaction_category)
    end
  end

  describe "#canonical_transactions" do
    it "queries by the outgoing hcb_code" do
      ct = create(:canonical_transaction)
      ct.update_column(:hcb_code, outgoing.hcb_code)

      expect(outgoing.canonical_transactions).to include(ct)
    end

    it "does not include transactions with the incoming hcb_code" do
      ct = create(:canonical_transaction)
      ct.update_column(:hcb_code, disbursement.incoming_hcb_code)

      expect(outgoing.canonical_transactions).not_to include(ct)
    end
  end

  describe "delegation" do
    it "delegates id to disbursement" do
      expect(outgoing.id).to eq(disbursement.id)
    end

    it "delegates name to disbursement" do
      expect(outgoing.name).to eq(disbursement.name)
    end

    it "delegates source_event to disbursement" do
      expect(outgoing.source_event).to eq(disbursement.source_event)
    end

    it "delegates destination_event to disbursement" do
      expect(outgoing.destination_event).to eq(disbursement.destination_event)
    end

    it "delegates fulfilled? to disbursement" do
      expect(outgoing.fulfilled?).to eq(disbursement.fulfilled?)
    end

    it "delegates reviewing? to disbursement" do
      expect(outgoing.reviewing?).to eq(disbursement.reviewing?)
    end

    it "delegates state to disbursement" do
      expect(outgoing.state).to eq(disbursement.state)
    end
  end
end
