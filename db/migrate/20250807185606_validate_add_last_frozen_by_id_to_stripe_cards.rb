class ValidateAddLastFrozenByIdToStripeCards < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :stripe_cards, :users
  end
end
