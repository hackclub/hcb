# frozen_string_literal: true

module BreakdownEngine
  class Tags
    def initialize(event, timeframe: nil)
      @event = event
      @timeframe = timeframe
    end

    def run
      tags = @event.tags.includes(hcb_codes: [:canonical_transactions, :canonical_pending_transactions]).each_with_object([]) do |tag, array|
        transactions = @timeframe.present? ? tag.hcb_codes.select { |hcb_code| hcb_code.date&.after?(@timeframe.ago) } : tag.hcb_codes
        amount_cents_sum = transactions.sum do |hcb_code|
          hcb_code.amount_cents.abs
        end
        next if amount_cents_sum == 0

        array << {
          name: tag.label,
          truncated: tag.label,
          value: Money.from_cents(amount_cents_sum).to_f
        }
      end

      tags.sort_by! { |tag| tag[:value] }.reverse!

      total_amount = tags.sum { |tag| tag[:value] }
      threshold = total_amount * 0.05

      if threshold > 0
        # Update tags to apply the threshold condition
        tags = tags.map do |tag|
          {
            name: tag[:name],
            truncated: tag[:truncated],
            value: (tag[:value] >= threshold ? tag[:value] : 0)
          }
        end

        # Calculate "Other" amount
        other_amount = total_amount - tags.sum { |tag| tag[:value] }
        if other_amount > 0
          tags << {
            name: "Other",
            truncated: "Other",
            value: other_amount
          }
        end
      end

      tags
    end

  end
end
