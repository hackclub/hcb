class RenameAchTransferAndIncreaseCheckColumn < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference :reimbursement_payout_holdings, :increase_check, index: {algorithm: :concurrently}
    add_reference :reimbursement_payout_holdings, :ach_transfer, index: {algorithm: :concurrently}
  end
end
