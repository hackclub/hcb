# frozen_string_literal: true

class GSuiteMailer < ApplicationMailer
  before_action :set_g_suite
  before_action :set_delivery_reason

  default to: -> { @g_suite.event.organizer_contact_emails(only_managers: true) }

  def notify_of_configuring
    mail subject: "[Action Requested] Your Google Workspace for #{@g_suite.domain} needs configuration"
  end

  def notify_of_verification_error
    mail subject: "[Action Required] Your Google Workspace for #{@g_suite.domain} encountered a verification error"
  end

  def notify_of_verified
    mail subject: "[Google Workspace Verified] Your Google Workspace for #{@g_suite.domain} has been verified"
  end

  def notify_of_error_after_verified
    mail subject: "[Action Required] Your Google Workspace for #{@g_suite.domain} is missing critical DNS records"
  end

  def notify_operations_of_entering_created_state
    @g_suite = GSuite.find(params[:g_suite_id])
    @delivery_reason = "you are on the HCB operations team."
    attrs = {
      to: ::ApplicationMailer::OPERATIONS_EMAIL,
      subject: "[OPS] [ACTION] [Google Workspace] Process #{@g_suite.domain}"
    }
    mail attrs
  end

  private

  def set_g_suite
    @g_suite = GSuite.find(params[:g_suite_id])
  end

  def set_delivery_reason
    @delivery_reason = "you are a manager of #{@g_suite.event.name}, which uses Google Workspace through HCB."
  end

end
