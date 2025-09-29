# frozen_string_literal: true

class UserSessionMailerPreview < ActionMailer::Preview
  def new_login
    user_session = UserSession.where.not(ip: "127.0.0.1").where.not(device_info: "").where.not(os_info: "").where.not(latitude: nil).last

    UserSessionMailer.new_login(user_session:)
  end

  def onboarded
    user = User.last

    UserSessionMailer.onboarded(user:)
  end

end
