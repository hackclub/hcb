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
    class TotalUsers < Metric
      include AppWide

      def calculate
        organizers.or(card_grant_recipients).or(reimbursement_report_users).count
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
