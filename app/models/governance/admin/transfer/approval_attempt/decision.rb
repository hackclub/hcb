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

              # 2. Based on the snapshot, find reasons to deny the attempt
              if attempted_amount_cents > current_limit_remaining_amount_cents
                self.result = :denied
                self.denial_reason = :insufficient_limit
              end

              # 3. Approve if no denial reasons were found
              self.result ||= :approved
            end

          end
        end

      end
    end
  end
end
