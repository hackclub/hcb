# frozen_string_literal: true

module TransactionEngine
  class NightlyJob < ApplicationJob
    queue_as :low
    include ::TransactionEngine::Shared

    def perform
      ::TransactionEngine::Nightly.new.run
    end

  end
end

module TransactionEngineJob
  Nightly = TransactionEngine::NightlyJob
end
