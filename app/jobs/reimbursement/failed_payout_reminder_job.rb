# frozen_string_literal: true

module Reimbursement
  class FailedPayoutReminderJob < ApplicationJob
    queue_as :low

    def perform
      Reimbursement::PayoutHolding
        .failed
        .where.not(failed_at: nil)
        .where(failed_reminders_sent: ...Reimbursement::PayoutHolding::REMINDER_DAYS.size)
        .find_each do |payout_holding|
          Rails.error.handle do
            payout_holding.with_lock do
              next unless payout_holding.failed?

              report = payout_holding.report
              next if report.reversed? || report.deleted?

              due = Reimbursement::PayoutHolding::REMINDER_DAYS.count { |days| payout_holding.failed_at <= days.days.ago }
              next if due <= payout_holding.failed_reminders_sent

              ReimbursementMailer.with(reimbursement_payout_holding: payout_holding).failed_payout_reminder.deliver_later
              payout_holding.update!(failed_reminders_sent: due)
            end
          end
        end
    end

  end

end
