# frozen_string_literal: true

module Api
  module Entities
    class Donation < LinkedObjectBase
      when_expanded do
        expose :amount, as: :amount_cents, documentation: { type: "integer" }
        expose :donor do
          expose :name
          expose :anonymous, documentation: { type: "boolean" }
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
        expose :message
        
        # Add UTM parameters
        expose :utm_params do
          expose :utm_source
          expose :utm_medium
          expose :utm_campaign
          expose :utm_term
          expose :utm_content
        end
      end

    end
  end
end
