# frozen_string_literal: true

class GSuiteMailer < ApplicationMailer
  before_action :set_g_suite

  default to: -> {
    emails = organization_managers
    emails << @g_suite.event.config.contact_email if @g_suite.event.config.contact_email.present?
    emails
  }

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

  def organization_managers
    @g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email_address_with_name)
  end

end
