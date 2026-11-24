# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::PayoutHolding, type: :model do
  before { create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING) }

  let(:report) { create(:reimbursement_report) }
  let(:payout_holding) { described_class.create!(report:, amount_cents: 130_00, aasm_state: :sent) }

  describe "#mark_failed", versioning: true do
    it "schedules a reminder after 3, 7, and 14 days tied to this failure" do
      freeze_time do
        payout_holding.mark_failed!
        failure_id = payout_holding.current_failure_id

        Reimbursement::PayoutHolding::REMINDER_DAYS.each do |days|
          expect(Reimbursement::FailedPayoutReminderJob).to have_been_enqueued.with(payout_holding, days, failure_id).at(days.days.from_now)
        end
      end
    end
  end
end
