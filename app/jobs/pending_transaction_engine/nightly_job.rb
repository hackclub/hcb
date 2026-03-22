# frozen_string_literal: true

module PendingTransactionEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    discard_on Exception do |job, error|
      Rails.error.report error
    end

    def perform
      ::PendingTransactionEngine::Nightly.new.run
    end

  end
end
