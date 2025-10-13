# frozen_string_literal: true

class WeeklyYswsEventSummaryJob < ApplicationJob
  queue_as :default
  def perform
    events = Event.ysws.where("events.created_at > ?", 7.days.ago)
    return if events.none?

    AdminMailer.with(events:).weekly_ysws_event_summary.deliver_now
  end

end
