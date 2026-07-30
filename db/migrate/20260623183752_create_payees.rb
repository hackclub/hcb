class CreatePayees < ActiveRecord::Migration[8.0]
  def change
    create_table :payees do |t|
      t.string :preferred_name, null: false
      t.belongs_to :legal_entity, null: false
      t.belongs_to :event, null: false

      t.index [:legal_entity_id, :event_id], unique: true

      t.timestamps
    end
  end
end
