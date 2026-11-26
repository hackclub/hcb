# frozen_string_literal: true

class RemoveUniqueTax1099TinHashIndexFromTaxForms < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :tax_forms, name: "index_tax_forms_unique_live_tax1099_tin_hash", algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :tax_forms, :tin_hash,
              unique: true,
              where: "source = 'tax1099' AND aasm_state <> 'discarded' AND deleted_at IS NULL",
              name: "index_tax_forms_unique_live_tax1099_tin_hash",
              algorithm: :concurrently
  end

end
