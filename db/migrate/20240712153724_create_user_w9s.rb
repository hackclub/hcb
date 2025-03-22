class CreateUserW9s < ActiveRecord::Migration[7.1]
  def change
    create_table :w9s do |t|
      t.bigint  :entity_id, null: false
      t.string  :entity_type, null: false
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.string :url, null: false
      t.datetime :signed_at, null: false

      t.timestamps
    end
  end
end
