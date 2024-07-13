class CreateBackupCodesLists < ActiveRecord::Migration[7.1]
  def change
    create_table :backup_codes_lists do |t|
      t.text :codes_ciphertext
      t.datetime :last_generated_at
      t.text :user_codes_ciphertext

      t.timestamps
    end
  end
end
