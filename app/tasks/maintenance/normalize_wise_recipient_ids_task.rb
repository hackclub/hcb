# frozen_string_literal: true

module Maintenance
  # One-time cleanup: reimbursement approvals used to save the pasted Wise recipient URL
  # (e.g. https://wise.com/recipients/<uuid>?new=undefined) onto the payout method as-is,
  # which broke the "Open <name> on Wise" button. Reduces every stored value to the bare
  # UUID, matching what `HasWiseRecipient#normalize_wise_recipient_id` does now.
  # Run once after deploying.
  class NormalizeWiseRecipientIdsTask < MaintenanceTasks::Task
    def collection
      LegalEntity::PayoutMethod::WiseTransfer.where.not(wise_recipient_id: nil).where.not("wise_recipient_id ~* ?", "^[0-9a-f-]{36}$")
    end

    def process(payout_method)
      payout_method.wise_recipient_id_will_change!
      payout_method.normalize_wise_recipient_id
      payout_method.update_columns(wise_recipient_id: payout_method.wise_recipient_id) if payout_method.wise_recipient_id_changed?
    end

  end
end
