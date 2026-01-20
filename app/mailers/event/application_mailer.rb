# frozen_string_literal: true

class Event
  class ApplicationMailer < ::ApplicationMailer
    before_action { @application = params[:application] }

    def confirmation
      mail to: @application.user.email_address_with_name, subject: "Thank you for applying to HCB!"
    end

    def under_review
      mail to: @application.user.email_address_with_name, subject: "Your HCB application is under review"
    end

    def incomplete
      mail to: @application.user.email_address_with_name, subject: "[Action Needed] Complete your HCB application!"
    end

  end

end
