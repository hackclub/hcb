# frozen_string_literal: true

module PendingEventMappingEngine
  module Decline
    class Stripe
      def run
        unsettled.find_each(batch_size: 100) do |cpt|
          rpst = cpt.raw_pending_stripe_transaction
          st = rpst.stripe_transaction

          status = st["status"]
          approved = st["approved"]

          # 1. identify declined (closed & not approved) transactions
          if status == "closed" && approved == false
            cpt.decline!
          end

          # 2. identify authed (0 amount and a considerable amount of time has passed)
          if rpst.amount_cents == 0 && Time.at(rpst.stripe_transaction["created"]).before?(30.days.ago)
            cpt.decline!
          end

          # 3. identify reversed
          if status == "reversed"
            cpt.decline!
          end

        end
      end

      private

      def unsettled
        CanonicalPendingTransaction.unsettled.stripe
      end

    end
  end
end
