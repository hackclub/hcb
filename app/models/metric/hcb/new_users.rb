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
  module Hcb
    class NewUsers < Metric
      include AppWide

      def calculate
        organizers.or(card_grant_recipients).or(reimbursement_report_users)
                  .where("EXTRACT(YEAR FROM users.created_at) = ?", Metric.year)
                  .count
      end

      private

      def included_models = %i[organizer_positions card_grants reimbursement_reports]

      def organizers
        ::User.includes(included_models).where.not(organizer_positions: { id: nil })
      end

      def card_grant_recipients
        ::User.includes(included_models).where.not(card_grants: { id: nil })
      end

      def reimbursement_report_users
        ::User.includes(included_models).where.not(reimbursement_reports: { id: nil })
      end

    end
  end

end
