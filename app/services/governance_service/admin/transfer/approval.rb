# frozen_string_literal: true

module GovernanceService
  module Admin
    module Transfer
      class Approval
        def initialize(transfer:, amount_cents:, user:)
          @transfer = transfer
          @amount_cents = amount_cents
          @user = user

          @request_context = Current.governance_request_context
          @approval_attempt = nil
        end

        def run
          ensure_may_approve!
        rescue Governance::Admin::Transfer::ApprovalAttempt::DeniedError
          false
        end

        def ensure_may_approve!
          @approval_attempt = new_approval_attempt

          # Prevent race conditions
          limit.with_lock do
            @approval_attempt.make_decision
            @approval_attempt.save!
          end

          unless @approval_attempt.successful?
            raise Governance::Admin::Transfer::ApprovalAttempt::DeniedError.new(@approval_attempt.denial_message)
          end

          true # Approval succeeded, return true
        end

        def may_approve?
          @approval_attempt = new_approval_attempt
          @approval_attempt.make_decision
          # Don't save to DB. We just want to check if it would be approved
          @approval_attempt.approved?
        rescue Governance::Admin::Transfer::Limit::MissingApprovalLimitError
          false
        end

        private

        def new_approval_attempt
          Governance::Admin::Transfer::ApprovalAttempt.new(
            transfer: @transfer,
            attempted_amount_cents: @amount_cents,
            user: @user,
            limit:,
            request_context: @request_context
          )
        end

        def limit
          @limit ||= Governance::Admin::Transfer::Limit.find_by(user: @user)
          unless @limit
            raise Governance::Admin::Transfer::Limit::MissingApprovalLimitError.new(
              "Unable to approve transfer. #{@user.name} does not have an admin transfer limit configured."
            )
          end

          @limit
        end

      end
    end
  end
end
