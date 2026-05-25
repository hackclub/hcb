# frozen_string_literal: true

# == Schema Information
#
# Table name: metrics
#
#  id            :bigint           not null, primary key
#  aasm_state    :string
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
# Indexes
#
#  index_metrics_on_subject                                        (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type_and_year  (subject_type,subject_id,type,year) UNIQUE
#
class Metric
  module User
    class TotalSpent < Metric
      include Subject

      def calculate
        card = RawStripeTransaction.joins("JOIN stripe_cardholders on raw_stripe_transactions.stripe_transaction->>'cardholder' = stripe_cardholders.stripe_id").where("EXTRACT(YEAR FROM date_posted) = ?", Metric.year).where(stripe_cardholders: { user_id: user.id }).sum(:amount_cents)
        ach = AchTransfer.where(creator_id: user.id, rejected_at: nil).where("EXTRACT(YEAR FROM created_at) = ?", Metric.year).sum(:amount)
        checks = Check.where(creator_id: user.id, rejected_at: nil).where("EXTRACT(YEAR FROM created_at) = ?", Metric.year).sum(:amount) + IncreaseCheck.where(user_id: user.id, increase_status: "deposited").where.not(approved_at: nil).where("EXTRACT(YEAR FROM created_at) = ?", Metric.year).sum(:amount)
        card.abs + ach.abs + checks.abs
      end

    end
  end

end
