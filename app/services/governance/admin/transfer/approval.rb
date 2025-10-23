module Governance
  module Admin
    module Transfer
      class Approval
        def initialize(transfer:, amount_cents:, user:)
          @transfer = transfer
          @amount_cents = amount_cents
          @user = user

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
          )

          # Prevent race conditions
          limit.with_lock do
            @approval_attempt.make_decision
            @approval_attempt.save!
          end

          unless @approval_attempt.approved?
            raise Transfer::ApprovalAttempt::DeniedError.new(@approval_attempt.denial_message)
          else
            true # Approval succeeded, return true
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
