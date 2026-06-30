class CreateTaxForms < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_forms do |t|
      t.string :aasm_state, null: false
      t.string :form_type

      t.string :external_service, null: false
      t.string :external_id

      t.string :address_city
      t.string :address_country
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state

      t.string :tin_hash
      
      t.belongs_to :legal_entity, null: false

      t.datetime :deleted_at
      t.timestamps
    end
  end
end
