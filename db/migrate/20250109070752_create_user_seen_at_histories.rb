class CreateUserSeenAtHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :user_seen_at_histories do |t|
      t.references :user, foreign_key: true
      t.datetime :period_start_at, null: false
      t.datetime :period_end_at, null: false
      t.timestamps
    end
  end
end
