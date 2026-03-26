# frozen_string_literal: true

module Api
  module Entities
    class CheckDeposit < LinkedObjectBase
      when_expanded do
        expose :amount_cents, documentation: { type: "integer" }
        format_as_date do
          expose :created_at, as: :date
        end
        expose :increase_status, as: :status, documentation: {
          values: %w[
            pending
            submitted
            manual_submission_required
            rejected
            returned
            deposited
          ]
        }

        expose_associated User do |check_deposit, options|
          check_deposit.created_by
        end

      end

      def self.entity_name
        "Check Deposit"
      end

    end
  end
end
