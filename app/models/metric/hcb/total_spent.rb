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
    class TotalSpent < Metric
      include AppWide

      def calculate
        CanonicalTransaction.included_in_stats
                            .where(date: Date.new(2024, 1, 1)..Date.new(2024, 12, 31))
                            .expense
                            .sum(:amount_cents)
      end

    end
  end

end
