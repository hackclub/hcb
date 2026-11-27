# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def onboarded(user:)
    @user = user
    @delivery_reason = "you created an HCB account."

    mail to: @user.email, subject: "Welcome to HCB!"
  end

end
