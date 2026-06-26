class AddLinkedObjectToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :ledger_items, :linked_object, polymorphic: true, null: true, index: {algorithm: :concurrently}
  end
end
