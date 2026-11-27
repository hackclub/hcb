# frozen_string_literal: true

module Reimbursement
  class FailedPayoutReminderJob < ApplicationJob
    queue_as :low
    discard_on ActiveJob::DeserializationError

    def perform(payout_holding, days, failure_id)
      return unless payout_holding.failed?
      return unless payout_holding.current_failure_id == failure_id
      # Failed Wise payouts aren't reattempted; the report is cancelled once Wise's refund is mapped.
      return if payout_holding.wise_transfer.present?

      report = payout_holding.report
      return if report.reversed? || report.deleted?

      ReimbursementMailer.with(reimbursement_payout_holding: payout_holding, days:).failed_payout_reminder.deliver_later
    end

  end

end
