# frozen_string_literal: true

class MonthlyDonationSummaryJob < ApplicationJob
  queue_as :default
  def perform
    Event.includes(:donations).where("donations.created_at > ?", 1.month.ago).references(:donations).find_each do |event|
      mailer = EventMailer.with(event: event)
      mailer.monthly_donation_summary.deliver_later
    end
  end

end
