class CreateRawPendingColumnTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :raw_pending_column_transactions do |t|
      t.string :column_id, null: false
      t.integer :column_event_type, null: false
      t.jsonb :column_transaction, null: false
      t.text :description, null: false
      t.date :date_posted, null: false
      t.integer :amount_cents, null: false
      t.timestamps
    end
    add_index :raw_pending_column_transactions, :column_id, unique: true
  end
end
