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
    class SpendingByUser < Metric
      include AppWide

      def calculate
        ActiveRecord::Base.connection.exec_query('
        SELECT
        users.id AS user_id,
        (SELECT SUM(dollars_spent) AS spent
        FROM (
            SELECT SUM(amount_cents) * -1 AS dollars_spent
            FROM "raw_stripe_transactions"
            WHERE raw_stripe_transactions.stripe_transaction->>\'cardholder\' IN (
                SELECT stripe_id FROM "stripe_cardholders" WHERE user_id = users.id
            ) AND EXTRACT(YEAR FROM date_posted) = 2024

            UNION ALL

            SELECT SUM(amount) AS dollars_spent
            FROM "ach_transfers"
            WHERE EXTRACT(YEAR FROM created_at) = 2024
            AND creator_id = users.id

            UNION ALL

            SELECT SUM(amount) AS dollars_spent
            FROM "disbursements"
            WHERE EXTRACT(YEAR FROM created_at) = 2024
            AND requested_by_id = users.id

            UNION ALL

            SELECT SUM(amount) AS dollars_spent
            FROM (
                SELECT amount
                FROM "increase_checks"
                WHERE EXTRACT(YEAR FROM created_at) = 2024
                AND user_id IN (users.id)
                UNION ALL
                SELECT amount
                FROM "checks"
                WHERE EXTRACT(YEAR FROM created_at) = 2024
                AND creator_id IN (users.id)
            ) AS combined_table
        ) AS combined_result)
        FROM "users"
        ORDER BY spent desc
        ').reject { |hash| hash["spent"].nil? }
                          .map { |item| [item["user_id"], item["spent"].to_i] }
                          .to_h
      end

      def metric
        # Unfortunately, jsonb columns don't maintain key order, so we have to re-sort. (json columns will keep key order tho)
        Rails.cache.fetch("#{cache_key_with_version}/metric", expires_in: 1.week) do
          # json doesn't support integer keys, so we have to convert them from strings back to ints
          super.sort_by { |_, spent| -spent }.to_h.transform_keys { |user_id| user_id.to_i }
        end
      end

    end
  end

end
