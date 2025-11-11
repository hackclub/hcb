class CreateEventApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :event_applications do |t|
      t.string :aasm_state
      t.string :airtable_record_id
      t.string :status

      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.boolean :political

      t.string :address_line1
      t.string :address_line2
      t.string :address_city
      t.string :address_state
      t.string :address_postal_code
      t.string :address_country

      t.string :reference
      t.string :referral_code

      t.text :notes

      t.timestamps
    end
  end
end
