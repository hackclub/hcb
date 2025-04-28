# frozen_string_literal: true

module PendingEventMappingEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    discard_on(StandardError) do |job, error|
      Airbrake.notify(error)
    end

    def perform
      ::PendingEventMappingEngine::Nightly.new.run
    end

  end
end

module PendingEventMappingEngineJob
  Nightly = PendingEventMappingEngine::NightlyJob
end
