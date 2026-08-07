class AddUniqueIndexToCardGrantsOnStripeCardId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :card_grants, :stripe_card_id

    add_index :card_grants, :stripe_card_id, unique: true, algorithm: :concurrently
  end
end
