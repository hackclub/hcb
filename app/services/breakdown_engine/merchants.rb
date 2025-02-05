# frozen_string_literal: true

module BreakdownEngine
  class Merchants
    include StripeAuthorizationsHelper

    def initialize(event, past_month: false)
      @event = event
      @past_month = past_month
    end

    def run
      merchants = RawStripeTransaction.select(
        "TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'network_id')) AS merchant",
        "string_agg(TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name')), ',') AS names",
        "SUM(raw_stripe_transactions.amount_cents) * -1 AS amount_cents"
      )
                                      .joins("LEFT JOIN canonical_transactions ct ON raw_stripe_transactions.id = ct.transaction_source_id AND ct.transaction_source_type = 'RawStripeTransaction'")
                                      .joins("LEFT JOIN canonical_event_mappings event_mapping ON ct.id = event_mapping.canonical_transaction_id")
                                      .where("event_mapping.event_id = ? #{"AND raw_stripe_transactions.created_at > NOW() - INTERVAL '1 month'" if @past_month}", @event.id)
                                      .group("merchant")
                                      .order(Arel.sql("SUM(raw_stripe_transactions.amount_cents) * -1 DESC"))
                                      .limit(15)
                                      .each_with_object([]) do |merchant, array|
        name = YellowPages::Merchant.lookup(network_id: merchant[:merchant]).name || merchant[:names].split(",").first.strip
        array << {
          truncated: name.truncate(15)&.titleize,
          name: name.titleize,
          value: merchant[:amount_cents].to_f / 100
        }
      end

      total_amount = merchants.sum { |merchant| merchant[:value] }
      threshold = total_amount * 0.05

      if threshold > 0
        # Update merchants to apply the threshold condition
        merchants = merchants.map do |merchant|
          {
            name: merchant[:name],
            truncated: merchant[:truncated],
            value: (merchant[:value] >= threshold ? merchant[:value] : 0)
          }
        end

        # Calculate "Other" amount
        other_amount = total_amount - merchants.sum { |merchant| merchant[:value] }
        if other_amount > 0
          merchants << {
            name: "Other",
            truncated: "Other",
            value: other_amount
          }
        end
      end

      merchants
    end

  end
end
