# frozen_string_literal: true

module Maintenance
  # Pulls each check deposit's status from Column to fix the ones that missed
  # a webhook. Column's `rejected` webhook used to go unhandled, so deposits
  # Column rejected are still marked as submitted.
  #
  # A status change runs the same callbacks as the webhook, so organizers get
  # the rejected, returned or deposited email for every deposit this fixes.
  class SyncCheckDepositsFromColumnTask < MaintenanceTasks::Task
    # A deposit Column fails to return (e.g. rate limited) is reported and
    # skipped; the task is safe to re-run to pick it up.
    report_on Faraday::Error

    def collection
      CheckDeposit.where.not(column_id: nil)
    end

    def process(check_deposit)
      check_deposit.sync_from_column!
    end

  end
end
