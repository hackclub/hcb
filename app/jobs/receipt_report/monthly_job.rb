# frozen_string_literal: true

module ReceiptReport
  class MonthlyJob < ApplicationJob
    queue_as :low
    def perform
      User.receipt_report_monthly.find_each(batch_size: 100) do |user|
        SendJob.perform_later(user.id)
      end
    end

  end
end

module ReceiptReportJob
  Monthly = ReceiptReport::MonthlyJob
end
