class RemoveGrantId < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :canonical_pending_transactions, :grant_id
    end
  end
end
