class CreateEventFollows < ActiveRecord::Migration[7.2]
  def change
    create_table :event_follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_follows, [:user_id, :event_id], unique: true
  end
end
