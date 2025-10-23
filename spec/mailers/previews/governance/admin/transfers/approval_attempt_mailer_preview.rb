# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class ApprovalAttemptMailerPreview < ActionMailer::Preview
        def report_denial
          @approval_attempt = Governance::Admin::Transfer::ApprovalAttempt.denied.last
          Governance::Admin::Transfer::ApprovalAttemptMailer.with(approval_attempt: @approval_attempt).report_denial
        end
      end
    end
  end
end
