class CreateWalkthroughs < ActiveRecord::Migration[7.2]
  def change
    create_table :walkthroughs do |t|
      t.timestamps
      t.string :key, null: false
      t.integer :progress, default: 0
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.index [:user_id, :event_id, :key], unique: true
    end
  end
end
