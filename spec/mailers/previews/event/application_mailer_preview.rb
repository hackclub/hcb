# frozen_string_literal: true

class Event
  class ApplicationMailerPreview < ActionMailer::Preview
    def confirmation
      Event::ApplicationMailer.with(application: Event::Application.last).confirmation
    end

    def under_review
      Event::ApplicationMailer.with(application: Event::Application.last).under_review
    end

    def incomplete
      Event::ApplicationMailer.with(application: Event::Application.last).incomplete
    end

    def rejected
      Event::ApplicationMailer.with(application: Event::Application.last).rejected
    end

  end

end
