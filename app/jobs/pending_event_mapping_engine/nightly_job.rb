# frozen_string_literal: true

module PendingEventMappingEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    discard_on(StandardError) do |job, error|
      Rails.error.report error
    end

    def perform
      ::PendingEventMappingEngine::Nightly.new.run
    end

  end
end
