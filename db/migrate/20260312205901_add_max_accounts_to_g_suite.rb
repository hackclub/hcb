class AddMaxAccountsToGSuite < ActiveRecord::Migration[8.0]
  def change
    add_column :g_suites, :max_accounts, :integer, default: 75, null: false
  end
end
