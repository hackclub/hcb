# frozen_string_literal: true

module Shared
  module AmpleBalance
    def self.ample_balance?(amount_cents = @amount_cents, event = @event)
      event.balance_available_v2_cents >= amount_cents # includes pending fees
    end

    def ample_balance?(...)
      AmpleBalance.ample_balance?(...)
    end
  end
end
