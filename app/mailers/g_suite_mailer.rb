# frozen_string_literal: true

class GSuiteMailer < ApplicationMailer
  def notify_of_configuring
    @recipient = params[:recipient]
    @g_suite = GSuite.find(params[:g_suite_id])

    mail to: @recipient,
         subject: "[Action Requested] Your Google Workspace for #{@g_suite.domain} needs configuration"
  end

  def notify_of_verification_error
    @recipient = params[:recipient]
    @g_suite = GSuite.find(params[:g_suite_id])

    mail to: @recipient.email_address_with_name,
         subject: "[Action Required] Your Google Workspace for #{@g_suite.domain} encountered a verification error"
  end

  def notify_of_verified
    @recipient = params[:recipient]
    @g_suite = GSuite.find(params[:g_suite_id])

    mail to: @recipient,
         subject: "[Google Workspace Verified] Your Google Workspace for #{@g_suite.domain} has been verified"
  end

  def notify_of_error_after_verified
    @recipient = params[:recipient]
    @g_suite = GSuite.find(params[:g_suite_id])

    mail to: @recipient.email_address_with_name,
         subject: "[Action Required] Your Google Workspace for #{@g_suite.domain} is missing critical DNS records"
  end

end
