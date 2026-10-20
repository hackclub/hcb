# frozen_string_literal: true

class GSuiteMailer < ApplicationMailer
  include IndividualDelivery

  before_action :set_g_suite

  def notify_of_configuring
    mail_individually recipients, subject: "[Action Requested] Your Google Workspace for #{@g_suite.domain} needs configuration"
  end

  def notify_of_verification_error
    mail_individually recipients, subject: "[Action Required] Your Google Workspace for #{@g_suite.domain} encountered a verification error"
  end

  def notify_of_verified
    mail_individually recipients, subject: "[Google Workspace Verified] Your Google Workspace for #{@g_suite.domain} has been verified"
  end

  def notify_of_error_after_verified
    mail_individually recipients, subject: "[Action Required] Your Google Workspace for #{@g_suite.domain} is missing critical DNS records"
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

  def recipients
    emails = @g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email_address_with_name)
    emails << @g_suite.event.config.contact_email if @g_suite.event.config.contact_email.present?
    emails
  end

end
