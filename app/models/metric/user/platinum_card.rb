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
    class PlatinumCard < Metric
      include Subject

      def calculate
        card = StripeCard.where(stripe_cardholder_id: StripeCardholder.where(user_id: user.id).select(:id))
                         .where(is_platinum_april_fools_2023: true)
                         .limit(1)
                         .first

        if card.nil?
          nil
        else
          {
            "organization"   => ::Event.find(card.event_id).name,
            "lastFourDigits" => card.last4
          }
        end
      end

    end
  end

end
