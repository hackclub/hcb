class CreatePayrollModels < ActiveRecord::Migration[7.1]
  def change
    create_table :employees do |t|
      t.bigint :entity_id, null: false
      t.string :entity_type, null: false
      t.belongs_to :event, null: false, foreign_key: true
      t.string :aasm_state
      t.timestamps
    end
    
    create_table :employee_payments do |t|
      t.belongs_to :employee, null: false, foreign_key: true

      t.text :title, null: false
      t.text :description
      
      t.integer :amount_cents, null: false, default: 0
      
      t.string :aasm_state

      t.datetime :approved_at
      t.datetime :rejected_at
      t.timestamps
    end
  end
end
