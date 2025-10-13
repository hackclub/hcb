class RemoveColumnsFromPayoutHolding < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :reimbursement_payout_holdings, :ach_transfers_id
      remove_column :reimbursement_payout_holdings, :increase_checks_id
    end
  end
end
