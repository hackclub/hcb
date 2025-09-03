class MigrateDataOnPayoutHolding < ActiveRecord::Migration[7.1]
  def change
    Reimbursement::PayoutHolding.update_all("ach_transfer_id = ach_transfers_id")
    Reimbursement::PayoutHolding.update_all("increase_check_id = increase_checks_id")
  end
end
