# frozen_string_literal: true

module Api
  module Entities
    class HcbFee < LinkedObjectBase
      when_expanded do
        expose :amount_cents, documentation: { type: "integer" }
        format_as_date do
          expose :created_at, as: :date
        end
        expose :aasm_state, as: :status, documentation: {
          values: %w[
            pending
            in_transit
            settled
          ]
        }

      end

      def self.entity_name
        "HCB Fee"
      end

    end
  end
end
