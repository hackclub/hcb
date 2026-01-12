# frozen_string_literal: true

class User
  class SecurityMailerPreview < ActionMailer::Preview
    def security_configuration_changed
      user = User.last

      User::SecurityMailer.security_configuration_changed(user:, change: "Two-factor authentication was enabled")
    end

  end

end
