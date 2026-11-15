# frozen_string_literal: true

class Subscription
  class DetectJob < ApplicationJob
    queue_as :low

    def perform(ledger_item)
      Subscription::Detect.new(ledger_item).run
    end

  end

end
