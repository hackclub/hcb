class RemoveAchPaymentId < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :canonical_pending_transactions, :ach_payment_id
    end
  end
end
