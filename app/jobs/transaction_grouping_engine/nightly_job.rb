# frozen_string_literal: true

module TransactionGroupingEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    include ::TransactionEngine::Shared

    def perform
      ::TransactionGroupingEngine::Nightly.new(start_date: last_1_month).run
    end

  end

end

module TransactionGroupingEngineJob
  Nightly = TransactionGroupingEngine::NightlyJob
end
