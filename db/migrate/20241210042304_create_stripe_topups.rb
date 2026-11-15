class CreateStripeTopups < ActiveRecord::Migration[7.2]
  def change
    create_table :stripe_topups do |t|
      t.timestamps
      t.string :stripe_id
      t.string :statement_descriptor, null: false
      t.jsonb :metadata
      t.string :description, null: false
      t.integer :amount_cents, null: false
    end
    add_index :stripe_topups, :stripe_id, unique: true
  end
end
