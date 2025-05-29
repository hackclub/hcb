# frozen_string_literal: true

module BreakdownEngine
  class Merchants
    include StripeAuthorizationsHelper

    def initialize(event, timeframe:)
      @event = event

      if Event::BREAKDOWN_TIMEFRAMES.values.include? timeframe
        @timeframe = timeframe
      end
    end

    def run
      time_limit = ""
      if @timeframe.present?
        time_limit = "AND raw_stripe_transactions.created_at > NOW() - INTERVAL '#{@timeframe}'"
      end

      merchants = RawStripeTransaction.select(
        "TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'network_id')) AS merchant",
        "string_agg(TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name')), ',') AS names",
        "SUM(raw_stripe_transactions.amount_cents) * -1 AS amount_cents"
      )
                                      .joins("LEFT JOIN canonical_transactions ct ON raw_stripe_transactions.id = ct.transaction_source_id AND ct.transaction_source_type = 'RawStripeTransaction'")
                                      .joins("LEFT JOIN canonical_event_mappings event_mapping ON ct.id = event_mapping.canonical_transaction_id")
                                      .where("event_mapping.event_id = ? #{time_limit}", @event.id)
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

      # Sort by value in descending order and limit to top 7 merchants
      merchants.sort_by! { |merchant| -merchant[:value] }
      merchants.first(7)
    end

  end
end
