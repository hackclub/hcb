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
    class SpendingByLocation < Metric
      include AppWide

      def calculate
        RawStripeTransaction.select(
          "CASE
            WHEN COALESCE(stripe_transaction->'merchant_data'->>'state', '') <> '' THEN
              TRIM(UPPER(
                  CONCAT_WS(' - ',
                      COALESCE(stripe_transaction->'merchant_data'->>'country', ''),
                      COALESCE(stripe_transaction->'merchant_data'->>'state', ''),
                      COALESCE(stripe_transaction->'merchant_data'->>'postal_code', '')
                  )
              ))
            ELSE
              TRIM(UPPER(
                  CONCAT_WS(' - ',
                      COALESCE(stripe_transaction->'merchant_data'->>'country', ''),
                      COALESCE(stripe_transaction->'merchant_data'->>'postal_code', '')
                  )
              ))
          END AS location",
          "(SUM(amount_cents)) * -1 AS amount_spent"
        )
                            .where("EXTRACT(YEAR FROM date_posted) = ?", 2024)
                            .group(
                              "CASE
            WHEN COALESCE(stripe_transaction->'merchant_data'->>'state', '') <> '' THEN
              TRIM(UPPER(
                  CONCAT_WS(' - ',
                      COALESCE(stripe_transaction->'merchant_data'->>'country', ''),
                      COALESCE(stripe_transaction->'merchant_data'->>'state', ''),
                      COALESCE(stripe_transaction->'merchant_data'->>'postal_code', '')
                  )
              ))
            ELSE
              TRIM(UPPER(
                  CONCAT_WS(' - ',
                      COALESCE(stripe_transaction->'merchant_data'->>'country', ''),
                      COALESCE(stripe_transaction->'merchant_data'->>'postal_code', '')
                  )
              ))
          END"
                            )
                            .order(Arel.sql("SUM(amount_cents) * -1 DESC"))
                            .each_with_object({}) { |item, hash| hash[self.geocode(item[:location])] = item[:amount_spent] }

      end

    end
  end

end
