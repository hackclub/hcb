# frozen_string_literal: true

class Event
  class OnboardingMailerPreview < ActionMailer::Preview
    def getting_started
      OnboardingMailer.with(event:, user:).getting_started
    end

    private

    def event
      Event.approved.not_demo_mode.last
    end

    def user
      event.organizer_positions.where(role: :manager).includes(:user).first.user
    end

  end

end
