class AddStaleToPersonalizationDesigns < ActiveRecord::Migration[7.0]
  def change
    add_column :stripe_card_personalization_designs, :stale, :boolean, null: false, default: false
    add_column :stripe_card_personalization_designs, :common, :boolean, null: false, default: false
  end
end
