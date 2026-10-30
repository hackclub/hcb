# frozen_string_literal: true

module Maintenance
  # Creates the weekly FeeReimbursementGroup for every HCB-900-<week> code that
  # predates groups. Creating the group links the week's existing ledger item to
  # it (FeeReimbursementGroup#assign_ledger_item!), so it renders as Stripe fee
  # reimbursements rather than a bare bank transaction, and the fee
  # reimbursements topped up under the code are attached to it. Zero-amount
  # reimbursements made no top-up and stay ungrouped, as new ones do.
  class BackfillFeeReimbursementGroupsTask < MaintenanceTasks::Task
    def collection
      HcbCode.where("hcb_code LIKE ?", "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE}-%")
    end

    def process(hcb_code)
      week = hcb_code.hcb_i2
      return unless week.match?(FeeReimbursementGroup::SLUG_REGEX)

      group = FeeReimbursementGroup.find_or_create_by!(slug: week)
      group.assign_ledger_item!

      # Matched on the top-up's statement descriptor, which is the code's short
      # code, so each reimbursement joins the group its bank debit belongs to.
      FeeReimbursement
        .where(fee_reimbursement_group: nil)
        .joins(:stripe_topup)
        .where(stripe_topups: { statement_descriptor: "HCB-#{hcb_code.short_code}" })
        .update_all(fee_reimbursement_group_id: group.id)
    end

  end
end
