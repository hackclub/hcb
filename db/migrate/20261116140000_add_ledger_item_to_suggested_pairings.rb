# frozen_string_literal: true

# A suggested pairing matches a receipt in the bin with one of the user's card
# charges. The charge's receipts are attached to its ledger item now
# (https://github.com/hackclub/hcb/issues/14106), so the pairing moves from the
# transaction's HCB code to its ledger item too
# (https://github.com/hackclub/hcb/issues/15698). Nullable until every pairing
# has been backfilled; hcb_code_id stays until the readers have switched.
class AddLedgerItemToSuggestedPairings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Each step commits on its own, so they're safe to re-run after a lock timeout.
  def up
    add_reference :suggested_pairings, :ledger_item, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true

    # A pairing is meaningless without its transaction, so it goes with it.
    add_foreign_key :suggested_pairings, :ledger_items, on_delete: :cascade, validate: false, if_not_exists: true
    validate_foreign_key :suggested_pairings, :ledger_items

    add_index :suggested_pairings, [:receipt_id, :ledger_item_id], unique: true, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_reference :suggested_pairings, :ledger_item, foreign_key: { to_table: :ledger_items }, index: true
  end

end
