class CreateDonationTiers < ActiveRecord::Migration[7.2]
  def change
    create_table :donation_tiers do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :name, null: false
      t.text :description
      t.string :image_url
      t.integer :position, null: false, default: 0

      t.datetime :deleted_at
      t.timestamps
    end
  end
end
