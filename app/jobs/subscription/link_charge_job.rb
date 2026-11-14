# frozen_string_literal: true

class Subscription
  class LinkChargeJob < ApplicationJob
    queue_as :low

    def perform(ledger_item)
      Subscription::LinkCharge.new(ledger_item:).run
    end

  end

end
