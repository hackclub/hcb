# frozen_string_literal: true

module StripeCardService
  class PredictSubscriptions
    def initialize(card:)
      @card = card
    end

    def run
      query = <<~SQL
        WITH potential_subscriptions AS (
          SELECT
              raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' as merchant,
              raw_stripe_transactions.stripe_transaction->>'card' as card,
              COUNT(*) as transaction_count,
              array_agg(raw_stripe_transactions.date_posted ORDER BY raw_stripe_transactions.date_posted DESC) as dates,
              array_agg(canonical_transactions.amount_cents ORDER BY raw_stripe_transactions.date_posted DESC) as amount_cents,
              array_agg(canonical_transactions.hcb_code ORDER BY raw_stripe_transactions.date_posted DESC) as hcb_codes
          FROM canonical_transactions
          LEFT JOIN raw_stripe_transactions
            ON raw_stripe_transactions.id = canonical_transactions.transaction_source_id
          WHERE transaction_source_type = 'RawStripeTransaction'
          AND raw_stripe_transactions.stripe_transaction->>'card' = '#{@card.stripe_id}'
          AND raw_stripe_transactions.date_posted >= NOW() - INTERVAL '6 months'
          GROUP BY merchant, card
        ),

        potential_subscriptions_with_date_differences AS (
          SELECT
              merchant,
              card,
              amount_cents,
              amount_cents[1] as last_amount_cents,
              transaction_count,
              dates,
              dates[1] as last_date,
              hcb_codes[1] as last_hcb_code,
              hcb_codes,
              array(
                  SELECT
                      (dates[i] - dates[i + 1])
                  FROM generate_series(1, array_length(dates, 1) - 1) AS i
              ) as date_differences
          FROM potential_subscriptions
        )

        SELECT
          merchant,
          card,
          hcb_codes,
          last_hcb_code,
          avg(unnested_date_differences) as average_date_difference,
          last_amount_cents,
          last_date,
          amount_cents,
          transaction_count,
          dates,
          stddev(unnested_date_differences),
          stddev(unnested_amount_cents)
        FROM potential_subscriptions_with_date_differences,
        LATERAL unnest(date_differences) as unnested_date_differences,
        unnest(amount_cents) as unnested_amount_cents
        WHERE transaction_count > 3
        GROUP BY merchant, card, amount_cents, transaction_count, dates, last_amount_cents, last_date, last_hcb_code, hcb_codes
        HAVING stddev(unnested_date_differences) < 5
           AND stddev(unnested_amount_cents) < 2
           AND avg(unnested_date_differences) > 5
        ORDER BY last_date DESC
      SQL

      result = ActiveRecord::Base.connection.exec_query(query)

      subscriptions = result.map do |row|
        {
          merchant: row["merchant"],
          card: row["card"],
          hcb_codes: row["hcb_codes"],
          last_hcb_code: row["last_hcb_code"],
          average_date_difference: row["average_date_difference"],
          updated_at: Time.current,
          created_at: Time.current
        }
      end

      Subscription.upsert_all(
        subscriptions,
        unique_by: [:merchant, :card]
      )
    end

  end
end
