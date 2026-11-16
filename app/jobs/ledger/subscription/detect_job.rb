# frozen_string_literal: true

class Ledger
  class Subscription
    class DetectJob < ApplicationJob
      queue_as :low
      # Queued from inside ledger writes (a charge settling, moving or being
      # refunded), which may not have committed yet.
      self.enqueue_after_transaction_commit = true

      retry_on Detect::Busy, wait: 1.minute, attempts: 30
      discard_on ActiveJob::DeserializationError

      def perform(ledger_item)
        Subscription::Detect.new(ledger_item).run
      end

    end

  end

end
