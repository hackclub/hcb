# frozen_string_literal: true

class MonthlyFollowerSummaryJob < ApplicationJob
  queue_as :default
  def perform
    Event.includes(:event_follows).where(event_follows: { created_at: Time.now.last_month.beginning_of_month.. }).find_each do |event|
      mailer = EventMailer.with(event: event)
      mailer.monthly_follower_summary.deliver_later
    end
  end

end
