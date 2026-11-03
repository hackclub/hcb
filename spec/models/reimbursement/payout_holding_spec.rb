# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::PayoutHolding, type: :model do
  before { create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING) }

  let(:report) { create(:reimbursement_report) }
  let(:payout_holding) { described_class.create!(report:, amount_cents: 130_00, aasm_state: :sent) }

  describe "#mark_failed" do
    it "schedules a reminder after 3, 7, and 14 days" do
      freeze_time do
        expect { payout_holding.mark_failed! }
          .to have_enqueued_job(Reimbursement::FailedPayoutReminderJob).with(payout_holding, 3).at(3.days.from_now)
          .and have_enqueued_job(Reimbursement::FailedPayoutReminderJob).with(payout_holding, 7).at(7.days.from_now)
          .and have_enqueued_job(Reimbursement::FailedPayoutReminderJob).with(payout_holding, 14).at(14.days.from_now)
      end
    end
  end
end
