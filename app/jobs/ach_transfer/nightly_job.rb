# frozen_string_literal: true

class AchTransfer
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      AchTransferService::Nightly.new.run
    end

  end

end

module AchTransferJob
  Nightly = AchTransfer::NightlyJob
end
