# frozen_string_literal: true

class Event
  class ApplicationReminderJob < ApplicationJob
    queue_as :low
    def perform(application, tip_number)
      return unless application.draft?

      Event::ApplicationMailer.with(application:, tip_number:).incomplete.deliver_later
    end

  end

end
