# frozen_string_literal: true

class MonthlyDonationSummaryJob < ApplicationJob
  queue_as :default
  def perform
    # Rate limit is 14/s, but putting 12 here to be safe and allow for other emails to be sent
    queue = Limiter::RateQueue.new(12, interval: 1)
    Event.includes(:donations).where("donations.created_at > ?", 1.month.ago).references(:donations).find_each do |event|
      queue.shift
      EventMailer.with(event: event).monthly_donation_summary.deliver_now
    end
  end

end
