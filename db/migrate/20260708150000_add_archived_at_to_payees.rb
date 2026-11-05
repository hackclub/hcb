class AddArchivedAtToPayees < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :payees, :archived_at, :datetime
    add_index :payees, :archived_at, algorithm: :concurrently
  end
end
