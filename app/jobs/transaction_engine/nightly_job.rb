# frozen_string_literal: true

module TransactionEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    include ::TransactionEngine::Shared

    def perform
      ::TransactionEngine::Nightly.new.run
      ::EventMappingEngine::Nightly.new.run

      # Finish-only check-in; see PendingTransactionEngine::NightlyJob for why
      # there's no start event.
      Appsignal::CheckIn.cron("transaction_engine_nightly_job")
    end

  end
end
