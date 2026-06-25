class RemoveFailedAtFromPayments < ActiveRecord::Migration[8.0]
  def change
    remove_column :payments, :failed_at, :datetime
  end
end
