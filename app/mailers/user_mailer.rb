# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def onboarded(user:)
    @user = user

    mail to: @user.email, subject: "Welcome to HCB!"
  end

end
