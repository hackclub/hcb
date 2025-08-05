# frozen_string_literal: true

class AdminMailerPreview < ActionMailer::Preview
  delegate :reminders, to: :AdminMailer

  def weekly_ysws_event_summary
    @events = Event.last(3)
    AdminMailer.with(events: @events).weekly_ysws_event_summary
  end

end
