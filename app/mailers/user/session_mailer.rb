# frozen_string_literal: true

class User
  class SessionMailer < ApplicationMailer
    def new_login(user_session:)
      @session = user_session
      @user = user_session.user
      @delivery_reason = "there was a new login to your HCB account."

      mail to: @user.email, subject: "New login to your HCB account"
    end

  end

end
