class CreateDonationTiers < ActiveRecord::Migration[7.2]
  def change
    create_table :donation_tiers do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :name, null: false
      t.text :description
      t.integer :sort_index

      t.datetime :deleted_at
      t.timestamps
    end

    add_column :events, :donation_tiers_enabled, :boolean, default: false, null: false
  end
end
