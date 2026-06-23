class CreatePayees < ActiveRecord::Migration[8.0]
  def change
    create_table :payees do |t|
      t.string :preferred_name
      t.belongs_to :legal_entity, null: false
      t.belongs_to :event, null: false

      t.timestamps
    end
  end
end
