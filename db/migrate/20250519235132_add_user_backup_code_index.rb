class AddUserBackupCodeIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :user_backup_codes, :code_hash, unique: true, algorithm: :concurrently
  end
end
