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
              "payments.data.payment.charge.balance_transaction",
              "payments.data.payment.payment_intent.latest_charge.balance_transaction"
            ]
          }
        end

      end
    end
  end
end
