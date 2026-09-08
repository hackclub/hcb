class CreateLegalEntity < ActiveRecord::Migration[8.0]
  def change
    create_table :legal_entities do |t|
      t.string :tin_hash

      t.string :address_city
      t.string :address_country
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state

      t.string :entity_type

      t.belongs_to :managing_event

      t.timestamps
    end
  end
end
