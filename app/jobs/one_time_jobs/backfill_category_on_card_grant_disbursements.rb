# frozen_string_literal: true

module OneTimeJobs
  class BackfillCategoryOnCardGrantDisbursements < ApplicationJob
    def perform
      disbursements = Disbursement.where.not(source_subledger_id: nil, destination_subledger_id: nil)
      slug = "grants-stipends"
      category = TransactionCategory.find_or_create_by!(slug:)

      disbursements.update(source_transaction_category: category, destination_transaction_category: category)

      hcb_codes = []
      disbursements.find_each(batch_size: 100) do |disbursement|
        hcb_codes << disbursement.incoming_hcb_code
        hcb_codes << disbursement.outgoing_hcb_code
      end

      CanonicalTransaction.where(hcb_code: hcb_codes).find_each(batch_size: 100) do |ct|
        TransactionCategoryService
          .new(model: ct)
          .set!(
            slug:,
            assignment_strategy: "automatic"
          )
      end

      CanonicalPendingTransaction.where(hcb_code: hcb_codes).find_each(batch_size: 100) do |cpt|
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
