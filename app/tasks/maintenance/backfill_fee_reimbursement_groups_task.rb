# frozen_string_literal: true

module Maintenance
  # Creates the weekly FeeReimbursementGroup for every HCB-900-<week> code that
  # predates groups. Creating the group links the week's existing ledger item to
  # it (FeeReimbursementGroup#assign_ledger_item!), so it renders as Stripe fee
  # reimbursements rather than a bare bank transaction, and the fee
  # reimbursements topped up that week are attached to it. The nightly job keyed
  # the week on its own run time (UTC), so processed_at's ISO week is the
  # group's week. Zero-amount reimbursements made no top-up and stay ungrouped,
  # as they do in FeeReimbursementService::Nightly.
  class BackfillFeeReimbursementGroupsTask < MaintenanceTasks::Task
    def collection
      HcbCode.where("hcb_code LIKE ?", "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE}-%")
    end

    def process(hcb_code)
      week = hcb_code.hcb_i2
      return unless week.match?(FeeReimbursementGroup::WEEK_REGEX)

      group = FeeReimbursementGroup.find_or_create_by!(week:)
      group.assign_ledger_item!

      FeeReimbursement
        .where(fee_reimbursement_group: nil)
        .where.not(stripe_topup_id: nil)
        .where("to_char(processed_at, 'IYYY_IW') = ?", week)
        .update_all(fee_reimbursement_group_id: group.id)
    end

  end
end
