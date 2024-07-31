class CreateStripePersonalizationDesigns < ActiveRecord::Migration[7.0]
  def change
    create_table :stripe_card_personalization_designs do |t|
      t.string :stripe_id 
      t.string :stripe_status
      t.string :stripe_name
      t.jsonb :stripe_carrier_text
      t.string :stripe_card_logo
      t.string :stripe_physical_bundle_id
      t.belongs_to :event, null: true, foreign_key: true

      t.timestamps
    end

    add_column :stripe_cards, :stripe_card_personalization_design_id, :integer, null: true
  end
end
