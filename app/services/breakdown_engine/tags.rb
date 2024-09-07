# frozen_string_literal: true

module BreakdownEngine
  class Tags
    def initialize(event)
      @event = event
    end

    def run
      tags = @event.tags.includes(hcb_codes: [:canonical_transactions, :canonical_pending_transactions]).each_with_object({}) do |tag, hash|
        amount_cents_sum = tag.hcb_codes.sum do |hcb_code|
          [hcb_code.amount_cents, 0].min
        end
        hash[tag.label] = (amount_cents_sum * -1).to_f / 100 if amount_cents_sum > 0
      end
    end

  end
end
