class CreateEmailUpdateModel < ActiveRecord::Migration[7.0]
  def change
    create_table :user_email_updates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :aasm_state, null: false
      t.string :original, null: false
      t.string :replacement, null: false
      t.string :authorization_token, null: false
      t.string :verification_token, null: false
      t.boolean :verified, null: false, default: false
      t.boolean :authorized, null: false, default: false
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
