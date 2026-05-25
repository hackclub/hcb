# frozen_string_literal: true

module Governance
  module Admin
    module Transfer
      class ApprovalAttempt
        module LimitSnapshot
          extend ActiveSupport::Concern

          included do
            monetize :current_limit_amount_cents
            monetize :current_limit_used_amount_cents
            monetize :current_limit_remaining_amount_cents

            private

            def snapshot_limit
              # This method should only be called on new records during creation
              raise ArgumentError if persisted?

              self.current_limit_window_started_at = limit.class.current_window_started_at
              self.current_limit_window_ended_at = limit.class.current_window_ended_at

              self.current_limit_amount_cents = limit.amount_cents
              self.current_limit_used_amount_cents = limit.used_amount_cents
              self.current_limit_remaining_amount_cents = limit.remaining_amount_cents
            end
          end
        end

      end
    end
  end
end
