class CreateRawIntrafiTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :raw_intrafi_transactions do |t|
      t.string :memo, null: false
      t.integer :amount_cents, null: false
      t.date :date_posted, null: false
      t.timestamps
    end
  end
end
