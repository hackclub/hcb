# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement::Incoming, type: :model do
  let(:disbursement) { create(:disbursement) }
  let(:incoming) { disbursement.incoming_disbursement }

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
    it "returns the value of the disbursement amount" do
      expect(incoming.amount).to eq(disbursement.amount)
    end
  end

  describe "#subledger" do
    context "when destination subledger is set" do
      let(:destination_event) { create(:event) }
      let(:destination_subledger) { create(:subledger, event: destination_event) }
      let(:disbursement_with_subledger) { create(:disbursement, event: destination_event, destination_subledger:) }
      let(:incoming_with_subledger) { disbursement_with_subledger.incoming_disbursement }

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

  describe "as a lens on the disbursement" do
    it "is a Disbursement::Incoming backed by the same persisted row" do
      expect(incoming).to be_a(Disbursement::Incoming)
      expect(incoming).to be_persisted
      expect(incoming.id).to eq(disbursement.id)
    end

    it "exposes the underlying disbursement via the reverse lens, same row" do
      expect(incoming.disbursement).to be_a(Disbursement)
      expect(incoming.disbursement.id).to eq(disbursement.id)
    end

    it "memoizes the lens (repeated reads return the same object)" do
      expect(disbursement.incoming_disbursement).to equal(disbursement.incoming_disbursement)
    end
  end

  describe ".polymorphic_name" do
    it "is the class name, so it round-trips through polymorphic associations" do
      expect(Disbursement::Incoming.polymorphic_name).to eq("Disbursement::Incoming")
    end
  end

  describe "#counterparty" do
    it "is the outgoing lens of the same transfer" do
      expect(incoming.counterparty).to be_a(Disbursement::Outgoing)
      expect(incoming.counterparty.id).to eq(disbursement.id)
    end
  end

  describe "counterparty aliases" do
    it "point at the source (sending) side" do
      expect(incoming.counterparty_event).to eq(disbursement.source_event)
      expect(incoming.counterparty_subledger).to eq(disbursement.source_subledger)
    end
  end
end
