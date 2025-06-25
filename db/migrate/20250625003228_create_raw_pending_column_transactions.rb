class CreateRawPendingColumnTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :raw_pending_column_transactions do |t|
      t.string :column_id
      t.integer :column_event_type
      t.jsonb :column_transaction
      t.text :description
      t.date :date_posted
      t.integer :amount_cents
      t.timestamps
    end
  end
end
