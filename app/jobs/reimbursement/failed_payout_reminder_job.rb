# frozen_string_literal: true

module Reimbursement
  class FailedPayoutReminderJob < ApplicationJob
    queue_as :low
    discard_on ActiveJob::DeserializationError

    def perform(payout_holding, days)
      return unless payout_holding.failed?

      report = payout_holding.report
      return if report.reversed? || report.deleted?

      ReimbursementMailer.with(reimbursement_payout_holding: payout_holding, days:).failed_payout_reminder.deliver_later
    end

  end

end
