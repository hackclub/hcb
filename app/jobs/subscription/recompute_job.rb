# frozen_string_literal: true

class Subscription
  class RecomputeJob < ApplicationJob
    queue_as :low
    # Queued while a charge moves to another ledger, which may not have
    # committed yet.
    self.enqueue_after_transaction_commit = true

    def perform(subscription_id)
      Subscription.find_by(id: subscription_id)&.recompute!
    end

  end

end
