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
        return "Miles (#{rate}¢/mile)" if currency == "USD"

        "Miles (#{rate}¢ USD/mile, converted to #{currency})"
      end

      # The mileage rate is in USD, so it's converted into the report's currency.
      def set_amount_cents
        usd_cents = (rate * value).round
        return self.amount_cents = usd_cents if currency == "USD" || usd_cents.zero?
        # The exchange rate is fixed when the miles are entered, on purpose: like a standard foreign expense, the
        # amount the submitter saw doesn't drift (or get un-approved) on later saves.
        return unless new_record? || value_changed? || type_changed? || reimbursement_report_id_changed?

        self.amount_cents = MoneyService.convert_from_usd_wise(usd_cents, currency)
      rescue Faraday::Error
        errors.add(:base, "We couldn't fetch the #{currency} exchange rate to convert mileage. Please try again.")
      end

      # For when something the amount depends on other than the miles changes (the report's currency or organization).
      def requote!
        value_will_change! # makes set_amount_cents requote
        save!
      end

    end

  end
end
