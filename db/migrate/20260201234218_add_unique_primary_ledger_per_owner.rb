class AddUniquePrimaryLedgerPerOwner < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Ensure each Event can have at most one primary ledger
    add_index :ledgers, :event_id,
              unique: true,
              where: "event_id IS NOT NULL",
              name: "index_ledgers_unique_event",
              algorithm: :concurrently

    # Ensure each CardGrant can have at most one primary ledger
    add_index :ledgers, :card_grant_id,
              unique: true,
              where: "card_grant_id IS NOT NULL",
              name: "index_ledgers_unique_card_grant",
              algorithm: :concurrently

    # Although it's not necessary to include the where `* IS NOT NULL`, it's
    # more efficient because it reduces the size of the index.
  end
end
