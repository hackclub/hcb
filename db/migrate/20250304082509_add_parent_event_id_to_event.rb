class AddParentEventIdToEvent < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :events, :parent, index: {algorithm: :concurrently}
  end
end