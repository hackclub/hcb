# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def email_update_authorization(request)
    @request = request

    mail to: @request.user.email_address_with_name, subject: "Authorize your new email address for HCB"
  end

  def email_update_verification(request)
    @request = request

    mail to: @request.replacement, subject: "Verify your new email address for HCB"
  end

  def backup_codes_generated(user:, session:)
    @user = user

    @session = session

    mail to: @user.email_address_with_name, subject: "Backup Codes generated for your HCB account"
  end

  def backup_code_used(user:, session:)
    @user = user

    @session = session

    mail to: @user.email_address_with_name, subject: "Backup Code used to access your HCB account"
  end

end
