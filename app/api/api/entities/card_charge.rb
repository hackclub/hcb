# frozen_string_literal: true

module Api
  module Entities

    class CardCharge < LinkedObjectBase
      when_expanded do
        expose :amount_cents, documentation: { type: "integer" }

        format_as_date do
          expose :date
        end

        expose :status, documentation: {
          type: "string",
          values: %w[pending closed reversed declined]
        } do |hcb_code|
          if hcb_code.pt&.declined?
            "declined"
          elsif hcb_code.stripe_reversed_by_merchant?
            "reversed"
          elsif hcb_code.canonical_transactions.any?
            "approved"
          else
            "pending"
          end
        end

        expose :decline_reason, documentation: { type: "string" } do |hcb_code|
          hcb_code.pt&.decline_reason&.to_s
        end

        expose :merchant do
          expose :merchant_name, as: :name, documentation: { type: "string" } do |hcb_code|
            hcb_code.stripe_merchant&.dig("name")
          end
          expose :merchant_category, as: :category, documentation: { type: "string" } do |hcb_code|
            hcb_code.stripe_merchant&.dig("category")
          end
          expose :merchant_country, as: :country, documentation: { type: "string" } do |hcb_code|
            hcb_code.stripe_merchant&.dig("country")
          end
          expose :merchant_network_id, as: :network_id, documentation: { type: "string" } do |hcb_code|
            hcb_code.stripe_merchant&.dig("network_id")
          end
        end

        expose :authorization_method, documentation: {
          type: "string",
          values: %w[keyed_in swipe chip contactless online]
        } do |hcb_code|
          hcb_code.pt&.raw_pending_stripe_transaction&.stripe_transaction&.dig("authorization_method") ||
            hcb_code.raw_stripe_transaction&.stripe_transaction&.dig("authorization_method")
        end

        expose_associated Card, hide: [Card, Organization, User] do |hcb_code, options|
          hcb_code.stripe_card
        end

        expose_associated User do |hcb_code, options|
          hcb_code.stripe_cardholder&.user
        end
      end

    end
  end
end
