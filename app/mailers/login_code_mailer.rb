# frozen_string_literal: true

class LoginCodeMailer < ApplicationMailer
  def send_code(email_address, pretty_login_code)
    @pretty_login_code = pretty_login_code
    @delivery_reason = "a login code was requested for this email address on HCB."

    mail(to: email_address, subject: "HCB Login Code: #{@pretty_login_code}")
  end

end
