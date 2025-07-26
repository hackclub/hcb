class CreateGSuiteAliases < ActiveRecord::Migration[7.1]
  def change
    create_table :g_suite_aliases do |t|
      t.text :address
      t.references :g_suite_account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
