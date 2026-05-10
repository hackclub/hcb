# frozen_string_literal: true

class Event
  class HideOnboardingMessagesJob < ApplicationJob
    queue_as :low

    def perform
      events = Event.joins(:config).where(config: { hide_onboarding_message: false })

      events.find_each do |event|
        event.config.update!(hide_onboarding_message: event.hcb_codes.size >= 5)
      end
    end

  end

end
