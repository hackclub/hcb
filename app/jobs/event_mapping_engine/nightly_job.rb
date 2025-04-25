# frozen_string_literal: true

module EventMappingEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      ::EventMappingEngine::Nightly.new.run
    end

  end
end

module EventMappingEngineJob
  Nightly = EventMappingEngine::NightlyJob
end
