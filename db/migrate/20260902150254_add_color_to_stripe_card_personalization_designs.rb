class AddColorToStripeCardPersonalizationDesigns < ActiveRecord::Migration[8.1]
  def change
    add_column :stripe_card_personalization_designs, :color, :string
  end
end
