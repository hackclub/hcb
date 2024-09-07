# frozen_string_literal: true

module TransactionEngineJob
  class Nightly < ApplicationJob
    queue_as :low
    include ::TransactionEngine::Shared

    def perform
      ::TransactionEngine::Nightly.new.run
    end

  end
end
