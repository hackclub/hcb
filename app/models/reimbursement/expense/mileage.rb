# frozen_string_literal: true

# == Schema Information
#
# Table name: reimbursement_expenses
#
#  id                      :bigint           not null, primary key
#  aasm_state              :string           not null
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
    class Mileage < ::Reimbursement::Expense
      # USD cents per mile. Unlike a standard expense's rate, this isn't in the
      # report's currency, so `amount_cents` needs converting (see below).
      def rate
        (event&.plan || Event::Plan::Standard.new).mileage_rate(created_at || Date.today) # rate may be used on creation, however, created_at isn't set at that point.
      end

      def value_label
        "Miles (#{rate}¢#{" USD" unless currency == "USD"}/mile)"
      end

      def usd_amount_cents
        (rate * value).round
      end

      # Only recomputed when the miles change: the conversion uses a live
      # exchange rate, so recomputing on every save (e.g. approving) could
      # nudge the amount and send the expense back to pending.
      def set_amount_cents
        recalculate_amount_cents if new_record? || value_changed?
      end

      def recalculate_amount_cents
        self.amount_cents = usd_amount_cents.zero? ? 0 : MoneyService.convert_from_usd(usd_amount_cents, currency)
      end

    end

  end
end
