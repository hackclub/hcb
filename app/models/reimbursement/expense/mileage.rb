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
      def rate
        (event&.plan || Event::Plan::Standard.new).mileage_rate(created_at || Date.today) # rate may be used on creation, however, created_at isn't set at that point.
      end

      def value_label
        "Miles (#{rate}¢#{" USD" unless currency == "USD"}/mile)"
      end

      # The mileage rate is in USD, so it's converted into the report's currency.
      def set_amount_cents
        usd_cents = (rate * value).round
        return self.amount_cents = usd_cents if currency == "USD" || usd_cents.zero?
        # Only requote when the miles change, so exchange rate drift doesn't alter (and un-approve) a saved expense.
        return unless new_record? || value_changed? || reimbursement_report_id_changed?

        self.amount_cents = MoneyService.convert_from_usd_wise(usd_cents, currency)
      rescue Faraday::Error
        errors.add(:base, "We couldn't fetch the #{currency} exchange rate for this mileage expense. Please try again.")
      end

    end

  end
end
