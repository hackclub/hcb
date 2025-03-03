# frozen_string_literal: true

module BreakdownEngine
  class Categories
    def initialize(event, past_month: false)
      @event = event
      @past_month = past_month
    end

    def run
      categories = RawStripeTransaction.select(
        "trim(upper(split_part(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'category', '*', 1))) AS category",
        "SUM(raw_stripe_transactions.amount_cents) * -1 AS amount_cents"
      )
                                       .joins("LEFT JOIN canonical_transactions ct ON raw_stripe_transactions.id = ct.transaction_source_id AND ct.transaction_source_type = 'RawStripeTransaction'")
                                       .joins("LEFT JOIN canonical_event_mappings event_mapping ON ct.id = event_mapping.canonical_transaction_id")
                                       .where("event_mapping.event_id = ? #{"AND raw_stripe_transactions.created_at > NOW() - INTERVAL '1 month'" if @past_month}", @event.id)
                                       .group("category")
                                       .order(Arel.sql("SUM(raw_stripe_transactions.amount_cents) * -1 DESC"))
                                       .each_with_object({}) do |merchant, object|
                                         categorizered = BreakdownEngine::Categorizer.new(merchant[:category].downcase).run
                                         if object[categorizered]
                                           object[categorizered][:value] += (merchant[:amount_cents].to_f / 100)
                                         else
                                           object[categorizered] = {
                                             truncated: categorizered.truncate(25).strip.titleize,
                                             name: categorizered.titleize,
                                             value: merchant[:amount_cents].to_f / 100
                                           }
                                         end
                                       end
                                       .values

      total_sum = categories.sum { |category| category[:value] }

      other = { name: "Other", truncated: "Other", value: 0 }
      filtered_categories = categories.each_with_object([]) do |category, arr|
        if category[:value] / total_sum < 0.05
          other[:value] += category[:value]
        else
          arr << category
        end
      end

      filtered_categories << other if other[:value] > 0
      filtered_categories
    end

  end
end
