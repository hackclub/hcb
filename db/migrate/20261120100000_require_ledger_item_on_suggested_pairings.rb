# frozen_string_literal: true

# Every suggested pairing is read through its ledger item now
# (https://github.com/hackclub/hcb/issues/15698), so the ledger item becomes
# required and the HCB code optional, ahead of dropping hcb_code_id once no
# running code writes it. The pairings without a ledger item (for the few HCB
# codes that have none) were never suggested, so they go.
class RequireLedgerItemOnSuggestedPairings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class SuggestedPairing < ActiveRecord::Base
    self.table_name = "suggested_pairings"

  end

  def up
    SuggestedPairing.where(ledger_item_id: nil).in_batches(of: 1_000, &:delete_all)

    add_check_constraint :suggested_pairings, "ledger_item_id IS NOT NULL", name: "suggested_pairings_ledger_item_id_null", validate: false
    validate_check_constraint :suggested_pairings, name: "suggested_pairings_ledger_item_id_null"
    change_column_null :suggested_pairings, :ledger_item_id, false
    remove_check_constraint :suggested_pairings, name: "suggested_pairings_ledger_item_id_null"

    change_column_null :suggested_pairings, :hcb_code_id, true
  end

  # rubocop:disable Rails/BulkChangeTable -- each statement commits on its own (see disable_ddl_transaction!)
  def down
    # Rolling back would fail to make hcb_code_id required again once pairings
    # have been written without one.
    if select_value("SELECT 1 FROM suggested_pairings WHERE hcb_code_id IS NULL LIMIT 1")
      raise ActiveRecord::IrreversibleMigration, "suggested pairings without an HCB code exist; remove them first"
    end

    change_column_null :suggested_pairings, :hcb_code_id, false
    change_column_null :suggested_pairings, :ledger_item_id, true
  end
  # rubocop:enable Rails/BulkChangeTable

end
