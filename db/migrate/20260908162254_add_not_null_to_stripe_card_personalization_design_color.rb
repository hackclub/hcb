class AddNotNullToStripeCardPersonalizationDesignColor < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :stripe_card_personalization_designs, "color IS NOT NULL", name: "stripe_card_personalization_designs_color_null", validate: false
  end
end
