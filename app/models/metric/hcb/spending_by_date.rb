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
    class SpendingByDate < Metric
      include AppWide

      def calculate
        CanonicalTransaction
          .group("date(canonical_transactions.created_at)")
          .select(
            "date(canonical_transactions.created_at) AS transaction_date",
            "SUM(CASE WHEN amount_cents < 0 THEN amount_cents * -1 ELSE 0 END) AS amount_spent",
            "SUM(CASE WHEN amount_cents > 0 THEN amount_cents ELSE 0 END) AS amount_raised",
            "SUM(amount_cents) AS net_amount"
          )
          .order("transaction_date ASC")
          .each_with_object({}) { |item, hash| hash[item[:transaction_date]] = item[:net_amount] }
      end

    end
  end

end
