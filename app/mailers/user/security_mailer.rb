# frozen_string_literal: true

class User
  class SecurityMailer < ApplicationMailer
    def security_configuration_changed(user:, change:)
      @user = user
      @change = change

      mail to: @user.email, subject: "Security settings changed on your HCB account"
    end

  end

end
