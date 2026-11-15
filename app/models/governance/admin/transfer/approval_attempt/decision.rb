# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class ApprovalAttempt
        module Decision
          extend ActiveSupport::Concern

          included do

            # Calls to this method should be wrapped in a lock on the associated
            # limit to prevent race conditions.
            def make_decision
              raise ActiveRecord::RecordInvalid.new("This approval attempt already has a result") unless result.nil?

              # 1. Take a snapshot of the limit right before the decision
              snapshot_limit

              # 2. Handle case where transfer was previously successfully
              #    approved by this user; in this case, we auto-approve the
              #    attempt.
              #
              #    We use pessimistic locking here to prevent race conditions.
              #    If there isn't a previously approved attempt, it is nil and
              #    the `if` condition is skipped. If there was a previously
              #    approved attempt and the lock is acquired, then it returns
              #    the record which is truthy.
              #    The lock on `previously_approved_attempt` is held until the
              #    wrapping transaction on the `limit` is committed (`limit.with_lock`).
              if previously_approved_attempt&.lock!
                return self.result = :redundantly_approved
              end

              # 3. Based on the snapshot, find reasons to deny the attempt
              if request_context&.impersonated?
                return deny_for :impersonation
              end

              if attempted_amount_cents > current_limit_remaining_amount_cents
                return deny_for :insufficient_limit
              end

              # 4. Approve if no denial reasons were found
              self.result ||= :approved
            end

          end

          def deny_for(denial_reason)
            self.result = :denied
            self.denial_reason = denial_reason

            self.result # return result
          end
        end

      end
    end
  end
end
