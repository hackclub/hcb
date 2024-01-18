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
#  index_metrics_on_subject  (subject_type,subject_id)
#
class Metric
  module Hcb
    class TotalUsers < Metric
      include AppWide

      def calculate
        ::User.includes(:organizer_positions)
              .where.not(organizer_positions: { id: nil })
              .count
      end

    end
  end

end
