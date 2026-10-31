# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::PayoutHolding, type: :model do
  before { create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING) }

  let(:report) { create(:reimbursement_report) }
  let(:payout_holding) { described_class.create!(report:, amount_cents: 130_00, aasm_state: :sent) }

  describe "#mark_failed" do
    it "records when the payout failed and resets the reminder count" do
      payout_holding.update!(failed_reminders_sent: 2)

      freeze_time do
        payout_holding.mark_failed!

        expect(payout_holding.reload.failed_at).to eq(Time.current)
        expect(payout_holding.failed_reminders_sent).to eq(0)
      end
    end

    it "starts the reminder cycle over when a retried payout fails again" do
      payout_holding.mark_failed!
      payout_holding.update!(failed_reminders_sent: 3)
      payout_holding.mark_settled!

      travel_to(10.days.from_now) do
        payout_holding.mark_sent!
        payout_holding.mark_failed!

        expect(payout_holding.reload.failed_at).to be_within(1.second).of(Time.current)
        expect(payout_holding.failed_reminders_sent).to eq(0)
      end
    end
  end
end
