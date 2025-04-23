# frozen_string_literal: true

module PendingTransactionEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    discard_on Exception do |job, error|
      Airbrake.notify(error)
    end

    def perform
      ::PendingTransactionEngine::Nightly.new.run
    end

  end
end

module PendingTransactionEngineJob
  Nightly = PendingTransactionEngine::NightlyJob
end
