class AddTinHashIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # tin_hash is the key every payment aggregates by (Tax::IdentificationNumber
    # looks up every legal entity sharing a TIN on each payable? check).
    add_index :legal_entities, :tin_hash, algorithm: :concurrently
    add_index :tax_forms, :tin_hash, algorithm: :concurrently
  end

end
