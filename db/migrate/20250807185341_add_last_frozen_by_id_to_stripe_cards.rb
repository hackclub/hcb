class AddLastFrozenByIdToStripeCards < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :stripe_cards, :last_frozen_by_id, :bigint
    add_index :stripe_cards, :last_frozen_by_id, algorithm: :concurrently
    add_foreign_key :stripe_cards, :users, column: :last_frozen_by_id, validate: false
  end
end
