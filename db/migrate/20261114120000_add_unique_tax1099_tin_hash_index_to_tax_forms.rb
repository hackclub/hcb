# frozen_string_literal: true

# At most one live Tax1099 import per TIN. Tax1099ImportService checks for a
# duplicate up front, but two imports of the same row racing each other (two
# tabs, two admins) would both pass that check; this makes the database the
# final word. Discarded and soft-deleted forms don't count, matching
# Tax::Form.not_discarded, so a discarded import can be redone.
class AddUniqueTax1099TinHashIndexToTaxForms < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :tax_forms, :tin_hash,
              unique: true,
              where: "source = 'tax1099' AND aasm_state <> 'discarded' AND deleted_at IS NULL",
              name: "index_tax_forms_unique_live_tax1099_tin_hash",
              algorithm: :concurrently
  end

  def down
    remove_index :tax_forms, name: "index_tax_forms_unique_live_tax1099_tin_hash", algorithm: :concurrently
  end

end
