# frozen_string_literal: true

module Api
  module Entities
    class Transfer < LinkedObjectBase
      when_expanded do
        expose :amount, as: :amount_cents
        expose :created_at, as: :date
        expose :v3_api_state, as: :status, documentation: {
          values: %w[
            fulfilled
            processing
            rejected
            canceled
            errored
            under_review
            pending
          ]
        }

        with_options(if: ->(obj, options) { obj.source_event&.is_public? }) do
          expose_associated Organization, as: :source_organization, hide: [API_LINKED_OBJECT_TYPE, Transaction] do |obj, options|
            obj.source_event
          end
        end

      end

    end
  end
end
