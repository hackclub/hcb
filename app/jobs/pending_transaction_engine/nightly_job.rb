# frozen_string_literal: true

module PendingTransactionEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    sidekiq_options retry: false
    discard_on(StandardError) do |job, error|
      Rails.error.report error
    end

    def perform
      Appsignal::CheckIn.cron("pending_transaction_engine_nightly_job") do
        ::PendingTransactionEngine::Nightly.new.run
      end
    end

  end
end
