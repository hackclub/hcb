class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.string :aasm_state
      t.string :airtable_record_id
      t.string :status

      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.boolean :political, null: false

      t.string :address_line1, null: false
      t.string :address_line2
      t.string :address_city, null: false
      t.string :address_state, null: false
      t.string :address_postal_code, null: false
      t.string :address_country, null: false

      t.string :reference, null: false
      t.string :referral_code

      t.text :notes

      t.timestamps
    end
  end
end
