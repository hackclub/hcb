# frozen_string_literal: true

class UserSessionMailer < ApplicationMailer
  def new_login(user_session:)
    @session = user_session
    @user = user_session.user

    mail to: @user.email, subject: "New login to your HCB account"
  end

  def onboarded(user:)
    @user = user

    mail to: @user.email, subject: "Welcome to HCB!"
  end

end
