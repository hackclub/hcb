# frozen_string_literal: true

module Api
  module Entities
    class Donation < LinkedObjectBase
      when_expanded do
        expose :amount, as: :amount_cents, documentation: { type: "integer" }
        expose :donor do
          expose :name
          expose :anonymous, documentation: { type: "boolean" }
          expose :avatar
        end
        format_as_date do
          expose :created_at, as: :date
        end
        expose :aasm_state, as: :status, documentation: {
          values: %w[
            pending
            in_transit
            deposited
            failed
            refunded
          ]
        }
        expose :recurring?, as: :recurring, documentation: { type: "boolean" }

      end

    end
  end
end
