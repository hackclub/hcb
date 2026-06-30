class AddCookedTransactionEggsToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :ledger_items, :cooked_transaction_eggs, polymorphic: true, index: {algorithm: :concurrently}
  end
end
