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
        if amount_cents_sum > 0
          hash[tag.label] = (amount_cents_sum * -1).to_f / 100
        end
      end

      total_amount = tags.values.sum
      threshold = total_amount * 0.05

      if threshold > 0
        tags = tags.transform_values do |amount|
          if amount >= threshold
            amount
          else
            0
          end
        end

        other_amount = total_amount - tags.values.sum
        if other_amount > 0
          tags["Other"] = other_amount
        end
      end

      tags
    end

  end
end
