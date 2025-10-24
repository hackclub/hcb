module Governance
  module Admin
    module Transfer
      class Approval
        def initialize(transfer:, amount_cents:, user:, request_context:)
          @transfer = transfer
          @amount_cents = amount_cents
          @user = user
          @request_context = request_context

          @approval_attempt = nil
        end

        def run
          ensure_may_approve!
        rescue Transfer::ApprovalAttempt::DeniedError
          false
        end

        def ensure_may_approve!
          @approval_attempt = ApprovalAttempt.new(
            transfer: @transfer,
            attempted_amount_cents: @amount_cents,
            user: @user,
            limit:,
            request_context: @request_context
          )

          # Prevent race conditions
          limit.with_lock do
            @approval_attempt.make_decision
            @approval_attempt.save!
          end

          if @approval_attempt.approved?
            true # Approval succeeded, return true
          else
            raise Transfer::ApprovalAttempt::DeniedError.new(@approval_attempt.denial_message)
          end
        end

        def limit
          @limit = Governance::Admin::Transfer::Limit.find_by(user: @user)
          raise MissingApprovalLimitError unless @limit

          @limit
        end

      end
    end
  end
end
