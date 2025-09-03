# frozen_string_literal: true

# == Schema Information
#
# Table name: reimbursement_expenses
#
#  id                      :bigint           not null, primary key
#  aasm_state              :string
#  amount_cents            :integer          default(0), not null
#  approved_at             :datetime
#  category                :integer
#  deleted_at              :datetime
#  description             :text
#  expense_number          :integer          not null
#  memo                    :text
#  type                    :string
#  value                   :decimal(, )      default(0.0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  approved_by_id          :bigint
#  reimbursement_report_id :bigint           not null
#
# Indexes
#
#  index_reimbursement_expenses_on_approved_by_id           (approved_by_id)
#  index_reimbursement_expenses_on_reimbursement_report_id  (reimbursement_report_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (reimbursement_report_id => reimbursement_reports.id)
#
module Reimbursement
  class Expense
    class Fee < ::Reimbursement::Expense
      # Fees are always charged in USD and therefore their amount should not be converted
      def conversion_rate
        1
      end

      def currency
        "USD"
      end

    end

  end
end
