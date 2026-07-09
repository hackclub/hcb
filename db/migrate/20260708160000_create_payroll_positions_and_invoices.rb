class CreatePayrollPositionsAndInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :payroll_positions do |t|
      t.belongs_to :payee, null: false, foreign_key: true
      t.belongs_to :contract, foreign_key: true

      t.text :title, null: false
      t.text :purpose, null: false
      t.integer :rate_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"

      t.date :start_date, null: false
      t.date :end_date, null: false

      t.string :aasm_state, null: false
      t.datetime :onboarding_at
      t.datetime :onboarded_at
      t.datetime :terminated_at

      t.timestamps
    end

    create_table :payroll_invoices do |t|
      t.belongs_to :payroll_position, null: false, foreign_key: true
      t.belongs_to :reviewed_by, foreign_key: { to_table: :users }
      t.belongs_to :payment, foreign_key: true

      t.text :name, null: false
      t.text :description

      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"

      t.string :aasm_state, null: false
      t.datetime :approved_at
      t.datetime :rejected_at

      t.timestamps
    end
  end
end
