# frozen_string_literal: true

module BreakdownEngine
  class Tags
    def initialize(event, start_date: nil, end_date: Time.now)
      @event = event
      @start_date = start_date
      @end_date = end_date
    end

    def run
      tags = @event.tags.includes(hcb_codes: [:canonical_transactions, :canonical_pending_transactions]).each_with_object([]) do |tag, array|
        transactions = tag.hcb_codes.select do |hcb_code|
          next false unless @start_date.nil? || hcb_code.date&.after?(@start_date)
          next false unless @end_date.nil? || hcb_code.date&.before?(@end_date)

          true
        end

        amount_cents_sum = transactions.sum { |hcb_code| hcb_code.amount_cents.abs }
        next if amount_cents_sum == 0

        array << {
          name: "#{tag.emoji} #{tag.label}",
          truncated: tag.label,
          value: Money.from_cents(amount_cents_sum).to_f
        }
      end

      # largest first
      tags.sort_by! { |tag| -tag[:value] }

      total_amount = tags.sum { |tag| tag[:value] }
      return [] if total_amount.zero?

      threshold = total_amount * 0.05

      if threshold > 0
        big_tags, small_tags = tags.partition { |tag| tag[:value] >= threshold }

        # ensure at least 10 slices total (9 tags + "Other") if there are enough tags
        min_visible_tags = 9
        if tags.size >= 10 && (big_tags.size + 1) < 10
          needed = min_visible_tags - big_tags.size
          # take largest "small" tags to show individually
          small_tags.sort_by! { |tag| -tag[:value] }
          big_tags.concat(small_tags.shift([needed, small_tags.size].min))
        end

        visible_tags = big_tags
        other_amount = total_amount - visible_tags.sum { |tag| tag[:value] }

        if other_amount > 0 && small_tags.any?
          visible_tags << {
            name: "Other",
            truncated: "Other",
            value: other_amount
          }
        end

        return visible_tags
      end

      tags
    end


  end
end
