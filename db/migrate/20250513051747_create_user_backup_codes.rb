class CreateUserBackupCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :user_backup_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :aasm_state
      t.text :code_hash, null: false
      t.text :salt, null: false

      t.timestamps
    end
  end
end
