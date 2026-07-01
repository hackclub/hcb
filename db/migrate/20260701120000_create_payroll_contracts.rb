# frozen_string_literal: true

class CreatePayrollContracts < ActiveRecord::Migration[7.2]
  def change
    create_table :payroll_contracts do |t|
      t.references :payee, null: false, foreign_key: true
      t.integer :hourly_rate_cents, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :purpose, null: false

      t.timestamps
    end
  end
end
