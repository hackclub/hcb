# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement::Outgoing, type: :model do
  let(:disbursement) { create(:disbursement) }
  let(:outgoing) { disbursement.outgoing_disbursement }

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
    it "returns the negative value of the disbursement amount" do
      expect(outgoing.amount).to eq(-disbursement.amount)
    end
  end

  describe "#subledger" do
    context "when source subledger is set" do
      let(:source_event) { create(:event) }
      let(:source_subledger) { create(:subledger, event: source_event) }
      let(:disbursement_with_subledger) { create(:disbursement, source_event:, source_subledger:) }
      let(:outgoing_with_subledger) { disbursement_with_subledger.outgoing_disbursement }

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

  describe "as a lens on the disbursement" do
    it "is a Disbursement::Outgoing backed by the same persisted row" do
      expect(outgoing).to be_a(Disbursement::Outgoing)
      expect(outgoing).to be_persisted
      expect(outgoing.id).to eq(disbursement.id)
    end

    it "exposes the underlying disbursement via the reverse lens, same row" do
      expect(outgoing.disbursement).to be_a(Disbursement)
      expect(outgoing.disbursement.id).to eq(disbursement.id)
    end

    it "memoizes the lens (repeated reads return the same object)" do
      expect(disbursement.outgoing_disbursement).to equal(disbursement.outgoing_disbursement)
    end
  end

  describe ".polymorphic_name" do
    it "is the class name, so it round-trips through polymorphic associations" do
      expect(Disbursement::Outgoing.polymorphic_name).to eq("Disbursement::Outgoing")
    end
  end

  describe "#counterparty" do
    it "is the incoming lens of the same transfer" do
      expect(outgoing.counterparty).to be_a(Disbursement::Incoming)
      expect(outgoing.counterparty.id).to eq(disbursement.id)
    end

    it "reads the counterparty amount as positive (the incoming leg)" do
      expect(outgoing.counterparty.amount).to eq(disbursement.amount)
    end
  end

  describe "counterparty aliases" do
    it "point at the destination (receiving) side" do
      expect(outgoing.counterparty_event).to eq(disbursement.destination_event)
      expect(outgoing.counterparty_subledger).to eq(disbursement.destination_subledger)
    end
  end
end
