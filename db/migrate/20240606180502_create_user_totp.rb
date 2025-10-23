class CreateUserTotp < ActiveRecord::Migration[7.1]
  def change
    create_table :user_totps do |t|
      t.belongs_to :user, null: false, index: true
      t.text :secret_ciphertext, null: false
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
