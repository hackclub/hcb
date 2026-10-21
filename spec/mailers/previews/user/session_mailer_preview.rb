# frozen_string_literal: true

class User
  class SessionMailerPreview < ActionMailer::Preview
    def new_login
      user_session = User::Session.where.not(ip: "127.0.0.1").where.not(device_info: "").where.not(os_info: "").where.not(latitude: nil).last

      User::SessionMailer.new_login(user_session:)
    end

  end

end
