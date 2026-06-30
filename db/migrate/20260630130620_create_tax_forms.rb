class CreateTaxForms < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_forms do |t|
      t.string :aasm_state, null: false
      t.datetime :sent_at
      t.datetime :completed_at
      t.datetime :tin_invalid
      t.datetime :failed_at

      t.string :form_type

      t.string :external_service, null: false
      t.string :external_id
      t.string :taxbandits_status

      t.string :address_city
      t.string :address_country
      t.string :address_line1
      t.string :address_line2
      t.string :address_postal_code
      t.string :address_state

      t.string :tin_hash
      t.string :document_url
      
      t.belongs_to :legal_entity, null: false

      t.datetime :deleted_at
      t.timestamps
    end
  end
end
