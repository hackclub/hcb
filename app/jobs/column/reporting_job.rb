# frozen_string_literal: true

module Column
  class ReportingJob < ApplicationJob
    queue_as :low
    def perform(date = DateTime.current.prev_month)
      start_date = date.beginning_of_month
      end_date = date.end_of_month

      ::ColumnService.schedule_bank_account_summary_report(
        from_date: start_date,
        to_date: end_date
      )

    end


  end
end
