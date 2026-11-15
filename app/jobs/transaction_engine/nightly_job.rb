# frozen_string_literal: true

module TransactionEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    include ::TransactionEngine::Shared

    def perform
      Appsignal::CheckIn.cron("transaction_engine_nightly_job") do
        ::TransactionEngine::Nightly.new.run
        ::EventMappingEngine::Nightly.new.run
      end
    end

  end
end
