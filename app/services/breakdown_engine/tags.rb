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
        amount_cents_sum = transactions.sum do |hcb_code|
          hcb_code.amount_cents.abs
        end
        next if amount_cents_sum == 0

        array << {
          name: "#{tag.emoji} #{tag.label}",
          truncated: tag.label,
          value: Money.from_cents(amount_cents_sum).to_f
        }
      end

      tags.sort_by! { |tag| tag[:value] }.reverse!

      total_amount = tags.sum { |tag| tag[:value] }

      tags
    end

  end
end
