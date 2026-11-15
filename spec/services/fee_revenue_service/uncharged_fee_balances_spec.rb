# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeRevenueService::UnchargedFeeBalances, type: :service do
  subject(:run) { described_class.new.run }

  describe "#run" do
    it "includes an organization whose only uncharged fees are on fronted revenue" do
      event = create(:event, plan_type: Event::Plan::Standard)
      donation = create(:canonical_pending_transaction, amount_cents: 100_00, fronted: true)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: donation, event:)

      expect(run).to contain_exactly({ event:, balance: 7_00 })
    end

    it "includes an organization that was charged within the last five days" do
      event = create(:event, last_fee_processed_at: 1.day.ago)
      create(:fee, canonical_event_mapping: nil, memo: "Revenue fee", event:, reason: :revenue, amount_cents_as_decimal: 5_00)

      expect(run).to contain_exactly({ event:, balance: 5_00 })
    end

    it "excludes an organization whose fees are already being charged" do
      event = create(:event)
      create(:fee, canonical_event_mapping: nil, memo: "Revenue fee", event:, reason: :revenue, amount_cents_as_decimal: 5_00)
      bank_fee = create(:canonical_pending_transaction, amount_cents: -5_00, raw_pending_bank_fee_transaction: create(:raw_pending_bank_fee_transaction))
      create(:canonical_pending_event_mapping, canonical_pending_transaction: bank_fee, event:)

      expect(run).to be_empty
    end

    it "orders organizations by balance, largest first" do
      smaller = create(:event)
      create(:fee, canonical_event_mapping: nil, memo: "Revenue fee", event: smaller, reason: :revenue, amount_cents_as_decimal: 3_00)
      larger = create(:event)
      create(:fee, canonical_event_mapping: nil, memo: "Revenue fee", event: larger, reason: :revenue, amount_cents_as_decimal: 9_00)

      expect(run.map { |item| item[:event] }).to eq([larger, smaller])
    end
  end
end
