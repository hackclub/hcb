# frozen_string_literal: true

class Ledger
  class Subscription
    class RecomputeJob < ApplicationJob
      queue_as :low
      # Queued from inside ledger writes (a charge settling, moving or being
      # refunded), which may not have committed yet.
      self.enqueue_after_transaction_commit = true

      retry_on Detect::Busy, wait: 1.minute, attempts: 30
      # A rebuild or another recompute deleted it in the meantime.
      discard_on ActiveRecord::RecordNotFound

      def perform(subscription_id)
        subscription = Subscription.find_by(id: subscription_id)
        return if subscription.nil?

        Subscription.transaction do
          Detect.lock!(subscription.ledger, subscription.merchant_key)
          subscription.recompute!
        end
      end

    end

  end

end
