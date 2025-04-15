# frozen_string_literal: true

module FeeEngine
  class HourlyJob < ApplicationJob
    queue_as :low
    def perform
      ::FeeEngine::Hourly.new.run
    end

  end
end

module FeeEngineJob
  Hourly = FeeEngine::HourlyJob
end
