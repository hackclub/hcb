# frozen_string_literal: true

class Event
  module Onboarding
    class GettingStartedEmailJob < ApplicationJob
      queue_as :default

      def perform(event)
        return if event.demo_mode?

        managers = event.organizer_positions.where(role: :manager).includes(:user).map(&:user)

        managers.each do |user|
          ::Event::Onboarding.with(event:, user:).getting_started.deliver_later
        end
      end

    end

  end

end
