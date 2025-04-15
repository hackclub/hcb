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
    class MostInteractedWith < Metric
      include Subject

      def calculate
        query = <<~SQL
          SELECT CONCAT(ach_transfers.creator_id, checks.creator_id, increase_checks.user_id, disbursements.requested_by_id, stripe_cardholders.user_id, paypal_transfers.user_id) as user_1, comments.user_id as user_2, COUNT(*) FROM "comments"
          JOIN "hcb_codes" on commentable_type = 'HcbCode' and hcb_codes.id = commentable_id
          LEFT JOIN "ach_transfers" on hcb_codes.hcb_code = CONCAT('HCB-300-', ach_transfers.id)
          LEFT JOIN "checks" on hcb_codes.hcb_code = CONCAT('HCB-400-', checks.id)
          LEFT JOIN "increase_checks" on hcb_codes.hcb_code = CONCAT('HCB-401-', increase_checks.id)
          LEFT JOIN "disbursements" on hcb_codes.hcb_code = CONCAT('HCB-500-', disbursements.id)
          LEFT JOIN "canonical_transactions" on hcb_codes.hcb_code = canonical_transactions.hcb_code
          LEFT JOIN "raw_stripe_transactions" on canonical_transactions.transaction_source_type = 'RawStripeTransaction' and canonical_transactions.transaction_source_id = raw_stripe_transactions.id
          LEFT JOIN "stripe_cardholders" on raw_stripe_transactions.stripe_transaction->>'cardholder' = stripe_cardholders.stripe_id
          LEFT JOIN "paypal_transfers" on hcb_codes.hcb_code = CONCAT('HCB-350-', paypal_transfers.id)
          WHERE
              comments.created_at >= '2024-01-01'
              AND CONCAT(ach_transfers.creator_id, checks.creator_id, increase_checks.user_id, disbursements.requested_by_id, stripe_cardholders.user_id, paypal_transfers.user_id) != '' AND CONCAT(ach_transfers.creator_id, checks.creator_id, increase_checks.user_id, disbursements.requested_by_id, stripe_cardholders.user_id, paypal_transfers.user_id) != CAST(comments.user_id as text)
              AND (CONCAT(ach_transfers.creator_id, checks.creator_id, increase_checks.user_id, disbursements.requested_by_id, stripe_cardholders.user_id, paypal_transfers.user_id) = '#{user.id}' OR comments.user_id = #{user.id})
              AND comments.user_id != 2891 -- This is the HCB user for automated comments
          GROUP BY CONCAT(ach_transfers.creator_id, checks.creator_id, increase_checks.user_id, disbursements.requested_by_id, stripe_cardholders.user_id, paypal_transfers.user_id), comments.user_id
          ORDER BY COUNT(*) DESC
        SQL

        stats = ActiveRecord::Base.connection.execute(query).to_a.each_with_object({}) do |item, hash|
          other_user_id = item["user_2"] == user.id ? item["user_1"].to_i : item["user_2"]
          hash[other_user_id] = (hash[other_user_id] || 0) + item["count"]
        end

        most_interacted_with = stats.max_by { |k, v| v }

        return nil if most_interacted_with.nil?

        most_interacted_with_user = ::User.find(most_interacted_with.first)

        { name: most_interacted_with_user.name, id: most_interacted_with_user.id, comments: most_interacted_with.last }
      end

      def metric
        # We're patching in user's profile picture here on demand (instead
        # storing it) so the link doesn't expire.

        user = ::User.find_by(id: super&.with_indifferent_access&.[](:id))
        image = ApplicationController.helpers.profile_picture_for(user)

        super&.merge({ "profile_picture" => image })
      end

    end
  end

end
