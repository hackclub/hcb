# frozen_string_literal: true

module Api
  module Entities
    class AchTransfer < LinkedObjectBase
      when_expanded do
        expose :amount, as: :amount_cents
        format_as_date do
          expose :created_at, as: :date
        end
        expose :aasm_state, as: :status, documentation: {
          values: %w[
            pending
            in_transit
            deposited
            rejected
          ]
        }
        expose :beneficiary do
          expose :recipient_name, as: :name
        end

        expose_associated User do |ach_transfer, options|
          ach_transfer.creator
        end

      end

      def self.entity_name
        "ACH Transfer" # this overrides the `entity_name` method defined by the Base class
      end

    end
  end
end
