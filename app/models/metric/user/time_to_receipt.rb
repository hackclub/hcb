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
#  type          :string           not null
#  year          :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  subject_id    :bigint
#  subject_type  :string
#
# Indexes
#
#  index_metrics_on_subject                                        (subject_type,subject_id)
#  index_metrics_on_subject_type_and_subject_id_and_type_and_year  (subject_type,subject_id,type,year) UNIQUE
#
class Metric
  module User
    class TimeToReceipt < Metric
      include Subject

      def calculate
        # A transaction's receipt may be attached to its HCB code or to its
        # ledger item (see Receiptable#receipts); measure from the HCB code's
        # creation either way.
        hcb_codes_join = <<~SQL.squish
          JOIN hcb_codes h
            ON (receipts.receiptable_type = 'HcbCode' AND receipts.receiptable_id = h.id)
            OR (receipts.receiptable_type = 'Ledger::Item' AND receipts.receiptable_id = h.ledger_item_id)
        SQL

        Receipt.joins(hcb_codes_join)
               .where("EXTRACT(YEAR FROM receipts.created_at) = ?", Metric.year)
               .where(user_id: user.id)
               .average("EXTRACT(EPOCH FROM (receipts.created_at - h.created_at))")
      end

    end
  end

end
