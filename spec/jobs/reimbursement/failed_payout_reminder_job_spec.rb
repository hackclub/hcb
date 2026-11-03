# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::FailedPayoutReminderJob do
  include ActiveJob::TestHelper

  let(:report) { create(:reimbursement_report) }
  let(:payout_holding) do
    create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
    Reimbursement::PayoutHolding.create!(report:, amount_cents: 130_00, aasm_state: :failed)
  end

  it "sends a reminder while the payout is still failed" do
    expect { described_class.perform_now(payout_holding, 7) }
      .to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
      .with(params: { reimbursement_payout_holding: payout_holding, days: 7 }, args: [])
  end

  it "does nothing once the payout is no longer failed" do
    payout_holding.mark_settled!

    expect { described_class.perform_now(payout_holding, 3) }
      .not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end

  it "skips payouts for reversed reports" do
    report.update_columns(aasm_state: "reversed")

    expect { described_class.perform_now(payout_holding, 3) }
      .not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end
end
