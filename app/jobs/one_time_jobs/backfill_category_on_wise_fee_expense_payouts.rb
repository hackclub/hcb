# frozen_string_literal: true

module OneTimeJobs
  class BackfillCategoryOnWiseFeeExpensePayouts < ApplicationJob
    def perform
      expense_payouts = Reimbursement::ExpensePayout.where(reimbursement_expenses_id: Reimbursement::Expense.where(type: "Reimbursement::Expense::Fee"))
      slug = "wise-fee"
      category = TransactionCategory.find_or_create_by!(slug:)

      hcb_codes = HcbCode.where(hcb_code: expense_payouts.select(:hcb_code))

      CanonicalTransaction.where(hcb_code: hcb_codes).find_each(batch_size: 100) do |ct|
        next unless ct.category.nil?

        TransactionCategoryService
          .new(model: ct)
          .set!(
            slug:,
            assignment_strategy: "automatic"
          )
      end

      CanonicalPendingTransaction.where(hcb_code: hcb_codes).find_each(batch_size: 100) do |cpt|
        next unless cpt.category.nil?

        TransactionCategoryService
          .new(model: cpt)
          .set!(
            slug:,
            assignment_strategy: "automatic"
          )
      end
    end

  end

end
