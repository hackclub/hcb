class AddReissuedForIdToIncreaseChecks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :increase_checks, :reissued_for_id, :bigint
    add_index :increase_checks, :reissued_for_id, algorithm: :concurrently
    add_foreign_key :increase_checks, :increase_checks, column: :reissued_for_id, validate: false
  end
end
