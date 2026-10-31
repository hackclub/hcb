# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::FailedPayoutReminderJob do
  include ActiveJob::TestHelper

  let(:failed_at) { Time.zone.local(2026, 10, 1, 12) }
  let(:report) { create(:reimbursement_report) }
  let!(:payout_holding) do
    create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
    travel_to(failed_at) do
      Reimbursement::PayoutHolding.create!(report:, amount_cents: 130_00, aasm_state: :sent).tap(&:mark_failed!)
    end
  end

  def run_job_at(time)
    expect { travel_to(time) { described_class.perform_now } }
  end

  it "does not send anything before the first threshold" do
    run_job_at(failed_at + 2.days).not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end

  it "sends a reminder after 3, 7, and 14 days" do
    [3, 7, 14].each_with_index do |days, index|
      run_job_at(failed_at + days.days).to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder).once
      expect(payout_holding.reload.failed_reminders_sent).to eq(index + 1)
    end
  end

  it "does not send the same reminder twice" do
    run_job_at(failed_at + 3.days).to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder).once
    run_job_at(failed_at + 3.days + 6.hours).not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end

  it "does not send anything after the last reminder" do
    payout_holding.update!(failed_reminders_sent: 3)

    run_job_at(failed_at + 30.days).not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end

  it "sends a single catch-up reminder if several thresholds were missed" do
    run_job_at(failed_at + 8.days).to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder).once
    expect(payout_holding.reload.failed_reminders_sent).to eq(2)
  end

  it "stops once the payout is no longer failed" do
    payout_holding.mark_settled!

    run_job_at(failed_at + 3.days).not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end

  it "skips payouts for reversed reports" do
    report.update_columns(aasm_state: "reversed")

    run_job_at(failed_at + 3.days).not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end

  it "ignores failed payouts that predate failure tracking" do
    payout_holding.update_columns(failed_at: nil)

    run_job_at(failed_at + 3.days).not_to have_enqueued_mail(ReimbursementMailer, :failed_payout_reminder)
  end
end
