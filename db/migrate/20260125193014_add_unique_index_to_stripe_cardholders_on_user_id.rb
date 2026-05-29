class AddUniqueIndexToStripeCardholdersOnUserId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :stripe_cardholders, :user_id

    add_index :stripe_cardholders, :user_id, unique: true, algorithm: :concurrently
  end
end
