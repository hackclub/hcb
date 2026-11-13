# frozen_string_literal: true

module Admin
  class IncomingFundsReportJob < ApplicationJob
    queue_as :low

    def perform
      ending_at = Time.current

      AdminMailer.with(starting_at: ending_at - 1.week, ending_at:).incoming_funds_report.deliver_later
    end

  end
end
