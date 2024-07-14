class CreateUserBackupCodesLists < ActiveRecord::Migration[7.1]
  def change
    create_table :user_backup_codes_lists do |t|
      t.text :codes_ciphertext
      t.datetime :last_generated_at
      t.datetime :deleted_at
      t.text :used_codes_ciphertext
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
