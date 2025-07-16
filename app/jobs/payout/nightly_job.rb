# frozen_string_literal: true

module Payout
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      ::PayoutService::Nightly.new.run
    end

  end
end
