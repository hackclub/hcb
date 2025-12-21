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
    class TotalSpent < Metric
      include AppWide

      def calculate
        CanonicalTransaction.included_in_stats
                            .where(date: Date.new(Metric.year, 1, 1)..Date.new(Metric.year, 12, 31))
                            .expense
                            .sum(:amount_cents)
      end

    end
  end

end
