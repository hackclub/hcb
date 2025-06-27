# frozen_string_literal: true

class WeeklyYswsEventSummaryJob < ApplicationJob
  queue_as :default
  def perform
    events = Event.ysws.where("created_at > ?", 7.days.ago)
    if events.length > 0
      mailer = AdminMailer.with(events:)
      mailer.weekly_ysws_event_summary.deliver_later
    end
  end

end
