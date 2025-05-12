# frozen_string_literal: true

class GSuite
  class RevocationMailer < ApplicationMailer
    before_action :set_g_suite_and_revocation, :set_reason, only: %i[notify_of_revocation revocation_warning revocation_one_week_warning]
    before_action :set_g_suite, only: %i[revocation_canceled]

    default to: -> {
      emails = organization_managers
      emails << @g_suite.event.config.contact_email if @g_suite.event.config.contact_email.present?
      emails
    }

    def revocation_warning
      mail subject: "[Action Required] Your Google Workspace access for #{@g_suite.domain} will be revoked on #{@g_suite_revocation.scheduled_at.strftime("%B %d, %Y")}"
    end

    def revocation_one_week_warning
      mail subject: "[Immediate Action Required] Your Google Workspace access for #{@g_suite.domain} will be revoked on #{@g_suite_revocation.scheduled_at.strftime("%B %d, %Y")}"
    end

    def notify_of_revocation
      mail subject: "Your Google Workspace access for #{@g_suite.domain} has been revoked"
    end

    def revocation_canceled
      mail subject: "We've canceled the revocation of your Google Workspace for #{@g_suite.domain}"
    end

    def set_g_suite_and_revocation
      @g_suite_revocation = GSuite::Revocation.find(params[:g_suite_revocation_id])
      @g_suite = @g_suite_revocation.g_suite
    end

    def set_g_suite
      @g_suite = GSuite.find(params[:g_suite_id])
    end

    def set_reason
      if @g_suite_revocation.because_of_invalid_dns?
        @reason = "you are missing required DNS records"
      elsif @g_suite_revocation.because_of_accounts_inactive?
        @reason = "all accounts on your domain have been inactive for the past six months"
      elsif @g_suite_revocation.because_of_other?
        @reason = @g_suite_revocation.other_reason
      else
        Rails.error.unexpected("GSuite::Revocation: Unknown reason for revocation")
        @reason = "of an unknown reason"
      end
    end

    def organization_managers
      @g_suite.event.organizer_positions.where(role: :manager).includes(:user).map(&:user).map(&:email_address_with_name)
    end

  end

end
