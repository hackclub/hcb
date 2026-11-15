# frozen_string_literal: true

class Subscription
  class DetectJob < ApplicationJob
    queue_as :low
    # Queued while a charge moves to another ledger, which may not have
    # committed yet.
    self.enqueue_after_transaction_commit = true

    def perform(ledger_item)
      Subscription::Detect.new(ledger_item).run
    end

  end

end
