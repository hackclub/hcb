class DropPayoutAndFailedAtFromPayment < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_reference :payments, :payout, polymorphic: true
      remove_column :payments, :failed_at, :datetime
    end
  end
end
