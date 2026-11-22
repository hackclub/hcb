# frozen_string_literal: true

module Maintenance
  # Reimbursement expenses used to be categorized with accounting codes
  # (Reimbursement::Expense.categories) that never reached the ledger, so
  # their payouts settled without a category unless the expense was a fee.
  # Expenses now store a transaction category slug instead, and the payout's
  # pending transaction gets it on create. This gives existing expenses the
  # transaction category closest to their legacy one, and their payouts'
  # pending and settled transactions the same, where they have none yet.
  class BackfillReimbursementExpenseTransactionCategoriesTask < MaintenanceTasks::Task
    LEGACY_CATEGORY_SLUGS = {
      "Advertising / Marketing"  => "marketing",
      "Customs Fees"             => "other-fees",
      "Dues & Subscriptions"     => "software-subscriptions",
      "Equipment & Furniture"    => "hardware-equipment",
      "Food & Entertainment"     => "food-fun",
      "Gifts"                    => "gifts",
      "Janitorial & Maintenance" => "miscellaneous",
      "Mileage"                  => "travel",
      "Office Supplies"          => "office",
      "Postage & Shipping"       => "shipping-postage",
      "Prizes"                   => "prizes",
      "Project Supplies"         => "project-supplies",
      "Software"                 => "software-subscriptions",
      "Taxes & Licenses"         => "taxes-filing-fees",
      "Technical Infrastructure" => "server-hosting",
      "Training"                 => "training",
      "Travel"                   => "travel",
    }.freeze

    def collection
      Reimbursement::Expense.where.not(category: nil).where(transaction_category_slug: nil)
    end

    def process(expense)
      slug = LEGACY_CATEGORY_SLUGS.fetch(expense.category)

      # update_columns: saving would re-run the approval reset in
      # Reimbursement::Expense's before_update, and this isn't an edit.
      expense.update_columns(transaction_category_slug: slug)

      payout = expense.expense_payout
      return unless payout

      [payout.canonical_pending_transaction, *payout.canonical_transactions].compact.each do |transaction|
        next if transaction.category_mapping.present?

        TransactionCategoryService.new(model: transaction).set!(slug:, assignment_strategy: "automatic")
      end
    end

  end
end
