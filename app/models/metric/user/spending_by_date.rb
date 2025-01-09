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
  module User
    class SpendingByDate < Metric
      include Subject

      def calculate

        stripe_transactions_subquery = RawStripeTransaction.select("date(date_posted) AS transaction_date, SUM(amount_cents) * -1 AS amount")
                                                           .where("raw_stripe_transactions.stripe_transaction->>'cardholder' IN (?)", StripeCardholder.select(:stripe_id).where(user_id: user.id))
                                                           .where("EXTRACT(YEAR FROM date_posted) = ?", 2024)
                                                           .group("date(date_posted)")

        ach_transfers_subquery = AchTransfer.select("date(created_at) AS transaction_date, SUM(amount) AS amount")
                                            .where("EXTRACT(YEAR FROM created_at) = ?", 2024)
                                            .where(creator_id: user.id)
                                            .group("date(created_at)")

        increase_checks_subquery = IncreaseCheck.select("date(created_at) AS transaction_date, SUM(amount) AS amount")
                                                .where("EXTRACT(YEAR FROM created_at) = ?", 2024)
                                                .where(user_id: user.id)
                                                .group("date(created_at)")

        checks_subquery = Check.select("date(created_at) AS transaction_date, SUM(amount) AS amount")
                               .where("EXTRACT(YEAR FROM created_at) = ?", 2024)
                               .where(creator_id: user.id)
                               .group("date(created_at)")

        combined_result_subquery = Arel.sql("(#{stripe_transactions_subquery.to_sql} UNION ALL #{ach_transfers_subquery.to_sql} UNION ALL #{increase_checks_subquery.to_sql} UNION ALL #{checks_subquery.to_sql}) AS combined_table")

        final_result = Arel.sql("SELECT date(transaction_date) AS transaction_date, SUM(amount) AS amount FROM #{combined_result_subquery} GROUP BY date(transaction_date) ORDER BY date(transaction_date) ASC")

        hash = {}
        (Date.new(2024, 1, 1)..Date.new(2024, 12, 31)).each do |date|
          hash[date.to_s] = 0
        end

        ActiveRecord::Base.connection.exec_query(final_result).each do |item|
          hash[item["transaction_date"]] = item["amount"].to_f
        end

        hash
      end

    end
  end

end
