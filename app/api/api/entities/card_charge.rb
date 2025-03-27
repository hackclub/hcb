# frozen_string_literal: true

module Api
  module Entities

    class CardCharge < LinkedObjectBase
      when_expanded do
        expose :amount_cents, documentation: { type: "integer" }

        format_as_date do
          expose :date
        end

        expose :merchant, using: Merchant do |hcb_code|
          stripe_transaction = hcb_code.ct&.raw_stripe_transaction&.stripe_transaction
          stripe_authorization = hcb_code.pt&.raw_pending_stripe_transaction&.stripe_transaction
          merchant_data = (stripe_transaction || stripe_authorization)&.dig("merchant_data")

          {
            name: merchant_data&.dig("name"),
            smart_name: begin
              humanized_merchant_name(merchant_data)
            rescue StandardError
              nil
            end,
            country: merchant_data&.dig("country"),
            network_id: merchant_data&.dig("network_id")
          }
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
