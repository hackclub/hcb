# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class ApprovalAttemptMailer < ApplicationMailer
        REPORT_RECIPIENTS = [
          "usr_8YEt6d", # Gary
          "usr_wVtRav", # Mel
          "usr_MVtap3", # Lucy
        ].freeze

        before_action :set_approval_attempt

        def report_denial
          impersonation_snippet = if @approval_attempt.impersonated?
                                    "#{@approval_attempt.impersonator.name} impersonating "
                                  end

          mail to: report_recipients,
               subject: "[HCB] Admin Transfer Denied: #{impersonation_snippet}#{@approval_attempt.user.name} for #{@approval_attempt.attempted_amount.format}"
        end

        private

        def report_recipients
          REPORT_RECIPIENTS.filter_map do |public_id|
            User.find_by_public_id(public_id)&.email_address_with_name
          end
        end

        def set_approval_attempt = @approval_attempt = params[:approval_attempt]

      end
    end
  end
end
