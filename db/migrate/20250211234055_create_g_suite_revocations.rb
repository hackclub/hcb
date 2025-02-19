class CreateGSuiteRevocations < ActiveRecord::Migration[7.2]
  def change
    create_table :g_suite_revocations do |t|
      t.boolean :invalid_dns, default: false, null: false
      t.boolean :no_account_activity, default: false, null: false
      t.boolean :other, default: false, null: false
      t.text :other_reason
      t.references :g_suite, null: false, foreign_key: true
      t.string :aasm_state

      t.timestamps
    end
  end
end
