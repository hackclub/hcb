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
  module User
    class SpendingByCategory < Metric
      include Subject

      def calculate
        RawStripeTransaction.select(
          "trim(upper(split_part(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'category', '*', 1))) AS category",
          "(SUM(raw_stripe_transactions.amount_cents)) * -1 AS amount_spent"
        )
                            .joins("JOIN stripe_cardholders on raw_stripe_transactions.stripe_transaction->>'cardholder' = stripe_cardholders.stripe_id")
                            .where("EXTRACT(YEAR FROM date_posted) = ?", Metric.year)
                            .where(stripe_cardholders: { user_id: user.id })
                            .group(
                              "trim(upper(split_part(raw_stripe_transactions.stripe_transaction->'merchant_data'->>'category', '*', 1)))"
                            )
                            .order(Arel.sql("SUM(raw_stripe_transactions.amount_cents) * -1 DESC"))
                            .each_with_object({}) { |item, hash| hash[item[:category]] = item[:amount_spent] }
      end

    end
  end

end
