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
      ::PendingTransactionEngine::Nightly.new.run

      # Finish-only check-in. A start event (the block form) would be sent again
      # by every restart of an interrupted run, and AppSignal counts each extra
      # start as a separate unscheduled run, leaving the scheduled one missed even
      # when the job completes in time.
      Appsignal::CheckIn.cron("pending_transaction_engine_nightly_job")
    end

  end
end
