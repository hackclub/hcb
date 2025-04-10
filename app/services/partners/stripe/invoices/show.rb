# frozen_string_literal: true

module Partners
  module Stripe
    module Invoices
      class Show
        include StripeService

        def initialize(id:)
          @id = id
        end

        def run
          ::StripeService::Invoice.retrieve(attrs)
        end

        private

        def attrs
          {
            id: @id,
            expand: [
              "charge",
              "charge.payment_method_details",
              "charge.balance_transaction"
            ]
          }
        end

      end
    end
  end
end
