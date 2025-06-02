# frozen_string_literal: true

class MonthlyDonationSummaryJob < ApplicationJob
  queue_as :bulk_email
  def perform
    Event.includes(:donations).where("donations.created_at > ?", 1.month.ago).references(:donations).find_each do |event|
      mailer = EventMailer.with(event: event)

      attempt = 1
      mail = nil
      while mail.nil?
        begin
          mail = mailer.monthly_donation_summary.deliver_now
        rescue Net::SMTPServerBusy
          # Rate limited by SES
          sleep 0.5 * attempt
          attempt += 1
        end
      end
    end
  end

end
