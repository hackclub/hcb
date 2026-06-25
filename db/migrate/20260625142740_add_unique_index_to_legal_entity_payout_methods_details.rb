class AddUniqueIndexToLegalEntityPayoutMethodsDetails < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :legal_entity_payout_methods,
                 column: [:details_type, :details_id],
                 name: "index_legal_entity_payout_methods_on_details",
                 algorithm: :concurrently

    add_index :legal_entity_payout_methods,
              [:details_type, :details_id],
              unique: true,
              name: "index_legal_entity_payout_methods_on_details",
              algorithm: :concurrently
  end
end
