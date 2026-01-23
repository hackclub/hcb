# frozen_string_literal: true

module Api
  module Entities
    class WiseTransfer < LinkedObjectBase
      when_expanded do
        expose :usd_amount_cents, as: :amount_cents, documentation: { type: "integer" }
        expose :currency, as: :local_currency, documentation: { type: "string" }
        expose :amount_cents, as: :local_amount_cents, documentation: { type: "integer" }
        format_as_date do
          expose :created_at, as: :date
        end
        expose :aasm_state, as: :status, documentation: {
          values: %w[
            pending
            approved
            rejected
            sent
            deposited
            failed
          ]
        }
        expose :beneficiary do
          expose :recipient_name, as: :name
        end

        expose_associated User do |wise_transfer, options|
          wise_transfer.user
        end

      end

      def self.entity_name
        "Wise Transfer"
      end

    end
  end
end
