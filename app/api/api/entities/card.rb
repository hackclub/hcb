# frozen_string_literal: true

module Api
  module Entities
    class Card < Base
      when_expanded do
        expose :name
        expose :card_type, as: :type, documentation: { type: "string", values: %w[virtual physical] }

        expose :status, documentation: {
          type: "string", values: %w[active inactive frozen canceled]
        } do |stripe_card, options|
          next "frozen" if stripe_card.frozen?

          stripe_card.stripe_status
        end

        format_as_date do
          expose :created_at, as: :issued_at
        end
      end

      expose_associated User, as: :owner do |stripe_card, options|
        stripe_card.stripe_cardholder.user
      end

      expose_associated Organization do |stripe_card, options|
        stripe_card.event
      end

    end
  end
end
