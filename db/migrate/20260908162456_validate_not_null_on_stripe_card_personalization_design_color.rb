class ValidateNotNullOnStripeCardPersonalizationDesignColor < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :stripe_card_personalization_designs, name: "stripe_card_personalization_designs_color_null"
    change_column_null :stripe_card_personalization_designs, :color, false
    remove_check_constraint :stripe_card_personalization_designs, name: "stripe_card_personalization_designs_color_null"
  end
end
