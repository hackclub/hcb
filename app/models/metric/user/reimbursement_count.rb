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
    class ReimbursementCount < Metric
      include Subject

      def calculate
        user.reimbursement_reports.where(aasm_state: %i[submitted reimbursement_requested reimbursement_approved reimbursed]).count
      end

    end
  end

end
