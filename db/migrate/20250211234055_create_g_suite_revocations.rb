class CreateGSuiteRevocations < ActiveRecord::Migration[7.2]
  def change
    create_table :g_suite_revocations do |t|
      t.integer :reason, default: 0, null: false
      t.text :other_reason
      t.references :g_suite, null: false, foreign_key: true
      t.string :aasm_state
      t.datetime :scheduled_at, null: false
      t.datetime :deleted_at
      t.boolean :one_week_notice_sent, default: false, null: false

      t.timestamps
    end
  end
end
