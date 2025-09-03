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
    class TimeToReceipt < Metric
      include Subject

      def calculate
        Receipt.joins("JOIN hcb_codes h ON receipts.receiptable_id = h.id")
               .where("EXTRACT(YEAR FROM receipts.created_at) = ?", 2024)
               .where(receiptable_type: "HcbCode")
               .where(user_id: user.id)
               .average("EXTRACT(EPOCH FROM (receipts.created_at - h.created_at))")
      end

    end
  end

end
