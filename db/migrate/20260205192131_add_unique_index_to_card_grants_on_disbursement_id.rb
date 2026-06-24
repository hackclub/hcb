class AddUniqueIndexToCardGrantsOnDisbursementId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :card_grants, :disbursement_id

    add_index :card_grants, :disbursement_id, unique: true, algorithm: :concurrently
  end
end
