# frozen_string_literal: true

class Cartel
  class ApplicationMailerPreview < ActionMailer::Preview
    def confirmation
      Cartel::ApplicationMailer.with(application: Cartel::Application.last).confirmation
    end

    def under_review
      Cartel::ApplicationMailer.with(application: Cartel::Application.last).under_review
    end

    def incomplete
      Cartel::ApplicationMailer.with(application: Cartel::Application.last).incomplete
    end

    def rejected
      Cartel::ApplicationMailer.with(application: Cartel::Application.last).rejected
    end

    def activated
      Cartel::ApplicationMailer.with(application: Cartel::Application.where.not(event: nil).last).activated
    end

  end

end
