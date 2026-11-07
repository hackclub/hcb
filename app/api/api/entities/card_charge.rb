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
          values: ::Ledger::Item.statuses.keys
        }

        expose :decline_reason, documentation: { type: "string" }, if: ->(charge, _options) { charge.status == "declined" }

        expose :merchant do
          %w[name category country network_id].each do |field|
            expose field, documentation: { type: "string" } do |charge|
              charge.merchant_data&.[](field)
            end
          end
        end

        expose :authorization_method, documentation: {
          type: "string",
          values: %w[keyed_in swipe chip contactless online]
        }

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
