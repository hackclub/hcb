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
    class TimeToReceipt < Metric
      include Subject

      def calculate
        Receipt.joins("JOIN hcb_codes h ON receipts.receiptable_id = h.id")
               .where("EXTRACT(YEAR FROM receipts.created_at) = ?", Metric.year)
               .where(receiptable_type: "HcbCode")
               .where(user_id: user.id)
               .average("EXTRACT(EPOCH FROM (receipts.created_at - h.created_at))")
      end

    end
  end

end
