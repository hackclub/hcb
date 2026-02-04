class CreateEventApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :event_applications do |t|
      t.string :aasm_state, null: false
      t.string :airtable_record_id
      t.string :airtable_status

      t.references :user, null: false, foreign_key: true
      t.references :event, foreign_key: true
      t.string :name
      t.text :description
      t.string :planning_duration
      t.text :political_description
      t.string :website_url
      t.boolean :teen_led
      t.integer :annual_budget_cents
      t.integer :committed_amount_cents
      t.integer :team_size
      t.string :funding_source
      t.boolean :currently_fiscally_sponsored
      t.string :project_category
      t.string :cosigner_email

      t.string :address_line1
      t.string :address_line2
      t.string :address_city
      t.string :address_state
      t.string :address_postal_code
      t.string :address_country

      t.string :referrer
      t.string :referral_code

      t.text :accessibility_notes

      t.string :last_page_viewed
      t.datetime :last_viewed_at

      t.datetime :submitted_at
      t.datetime :under_review_at
      t.datetime :approved_at
      t.datetime :rejected_at

      t.timestamps
    end
  end
end
