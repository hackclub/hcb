# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  let(:event) { create(:event) }

  it "is valid" do
    expect(event).to be_valid
  end

  it "defaults to approved" do
    expect(event).to be_approved
  end

  describe "#balance_v2_cents" do
    before do
      tx1 = create(:canonical_transaction, amount_cents: 100)
      tx2 = create(:canonical_transaction, amount_cents: 300)
      create(:canonical_event_mapping, canonical_transaction: tx1, event:)
      create(:canonical_event_mapping, canonical_transaction: tx2, event:)
    end

    it "calculates a value from canonical transactions" do
      result = event.balance_v2_cents

      expect(result).to eql(400).and eql(event.balance)
    end
  end

  describe "private" do
    before do
      create(:fee_relationship, fee_applies: true, event:, fee_amount: 10010)
      fee_payment = create(:transaction, amount: -10)
      create(:fee_relationship, is_fee_payment: true, event:, t_transaction: fee_payment)
    end
  end

  describe "#search_name" do
    context "when the search is a partial match" do
      it "returns the event" do
        event = create(:event, name: "Now in Ukraine")

        expect(Event.search_name("now in ukraine")).to contain_exactly(event)
        expect(Event.search_name("now in")).to contain_exactly(event)
        expect(Event.search_name("now")).to contain_exactly(event)
      end
    end
  end

  describe "total_fee_payments_v2_cents" do
    it "handles fee payments with an unknown hcb code" do
      # There are a few fee payments in prod that DON'T have an HCB-700 code.

      event = create(:event)

      expect {
        cem = create(
          :canonical_event_mapping,
          canonical_transaction: create(:canonical_transaction, amount_cents: -1000, hcb_code: "HCB-000-1"),
          event:,
          fee: create(:fee, reason: :hack_club_fee),
        )
      }.to change { event.reload.total_fee_payments_v2_cents }.from(0).to(1000)
    end
  end
end
