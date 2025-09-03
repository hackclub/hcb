class DropGsuiteAccountColumns < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :g_suite_accounts, :verified_at
      remove_column :g_suite_accounts, :rejected_at
    end
  end
end
