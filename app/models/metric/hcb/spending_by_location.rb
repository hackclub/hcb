# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id            :bigint           not null, primary key
#  aasm_state    :string           not null
#  canceled_at   :datetime
#  completed_at  :datetime
#  failed_at     :datetime
#  metric        :jsonb
#  processing_at :datetime
#  subject_type  :string
#  type          :string           not null
#  year          :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  subject_id    :bigint
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
                            .where("EXTRACT(YEAR FROM date_posted) = ?", Metric.year)
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
