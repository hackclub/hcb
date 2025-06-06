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
  module Event
    class SpendingByMerchant < Metric
      include Subject

      def calculate
        RawStripeTransaction.select(
          "CASE
             WHEN raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' SIMILAR TO '(SQ|GOOGLE|TST|RAZ|INF|PayUp|IN|INT|\\*)%'
               THEN TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name'))
             ELSE TRIM(UPPER(SPLIT_PART(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name', '*', 1)))
           END AS merchant_name",
          "SUM(raw_stripe_transactions.amount_cents) * -1 AS amount_spent"
        )
                            .joins("LEFT JOIN canonical_transactions ct ON raw_stripe_transactions.id = ct.transaction_source_id AND ct.transaction_source_type = 'RawStripeTransaction'")
                            .joins("LEFT JOIN canonical_event_mappings event_mapping ON ct.id = event_mapping.canonical_transaction_id")
                            .where("EXTRACT(YEAR FROM date_posted) = ?", 2024)
                            .where("event_mapping.event_id = ?", event.id)
                            .group(
                              "CASE
               WHEN raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name' SIMILAR TO '(SQ|GOOGLE|TST|RAZ|INF|PayUp|IN|INT|\\*)%'
                 THEN TRIM(UPPER(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name'))
               ELSE TRIM(UPPER(SPLIT_PART(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'name', '*', 1)))
             END"
                            )
                            .order(Arel.sql("SUM(raw_stripe_transactions.amount_cents) * -1 DESC"))
                            .each_with_object({}) { |item, hash| hash[item[:merchant_name]] = item[:amount_spent] }
      end

    end
  end

end
