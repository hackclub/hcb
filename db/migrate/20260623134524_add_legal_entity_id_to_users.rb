class AddLegalEntityIdToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :users, :legal_entity, index: {algorithm: :concurrently}
  end
end
