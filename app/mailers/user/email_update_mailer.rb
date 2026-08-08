# frozen_string_literal: true

class User
  class EmailUpdateMailer < ApplicationMailer
    before_action { @delivery_reason = "you requested to change your email address for HCB." }
    def authorization(request)
      @request = request

      mail to: @request.user.email_address_with_name, subject: "Authorize your new email address for HCB"
    end

    def verification(request)
      @request = request

      mail to: @request.replacement, subject: "Verify your new email address for HCB"
    end

  end

end
