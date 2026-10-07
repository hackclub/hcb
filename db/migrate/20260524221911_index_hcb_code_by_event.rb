class IndexHcbCodeByEvent < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :hcb_codes, :event_id, algorithm: :concurrently
  end
end
