class ValidateNotNullOnStripeCardPersonalizationDesignColor < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :stripe_card_personalization_designs, name: "stripe_card_personalization_designs_color_null"
    change_column_null :stripe_card_personalization_designs, :color, false
    remove_check_constraint :stripe_card_personalization_designs, name: "stripe_card_personalization_designs_color_null"
  end

  def down
    change_column_null :stripe_card_personalization_designs, :color, true
    add_check_constraint :stripe_card_personalization_designs, "color IS NOT NULL", name: "stripe_card_personalization_designs_color_null", validate: false
  end
end
