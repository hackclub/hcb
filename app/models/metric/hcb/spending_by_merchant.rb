# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id           :bigint           not null, primary key
#  metric       :jsonb
#  subject_type :string
#  type         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint
#
# Indexes
#
#  index_metrics_on_subject                               (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type  (subject_type,subject_id,type) UNIQUE
#
class Metric
  module Hcb
    class SpendingByMerchant < Metric
      include AppWide

      def calculate
        RawStripeTransaction.select(
          "raw_stripe_transactions.stripe_transaction->'merchant_data'->>'network_id' AS merchant_network_id",
          "CASE
             WHEN raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' SIMILAR TO '(SQ|GOOGLE|TST|RAZ|INF|PayUp|IN|INT|\\*)%'
               THEN TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name'))
             ELSE TRIM(UPPER(SPLIT_PART(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name', '*', 1)))
           END AS merchant_name",
          "SUM(raw_stripe_transactions.amount_cents) * -1 AS amount_spent"
        )
                            .joins("LEFT JOIN canonical_transactions ct ON raw_stripe_transactions.id = ct.transaction_source_id AND ct.transaction_source_type = 'RawStripeTransaction'")
                            .where("EXTRACT(YEAR FROM date_posted) = ?", 2024)
                            .group(
                              "raw_stripe_transactions.stripe_transaction->'merchant_data'->>'network_id'",
                              "CASE
               WHEN raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' SIMILAR TO '(SQ|GOOGLE|TST|RAZ|INF|PayUp|IN|INT|\\*)%'
                 THEN TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name'))
               ELSE TRIM(UPPER(SPLIT_PART(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name', '*', 1)))
             END"
                            )
                            .having("count(*) > 10") # TODO: this is a temp hack to prevent leaking transaction specific data such as an order number.
                            .order(Arel.sql("SUM(raw_stripe_transactions.amount_cents) * -1 DESC"))
                            .each_with_object({}) do |item, hash|
                              name = YellowPages::Merchant.lookup(network_id: item.merchant_network_id).name
                              hash[name || item.merchant_name] ||= 0
                              hash[name || item.merchant_name] += item[:amount_spent]
                            end
      end

    end
  end

end
