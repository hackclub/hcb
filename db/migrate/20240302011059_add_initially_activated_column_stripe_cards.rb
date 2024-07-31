class AddInitiallyActivatedColumnStripeCards < ActiveRecord::Migration[7.0]
  def up
    add_column :stripe_cards, :initially_activated, :boolean, default: false, null: false
  end

  def down
    remove_column :stripe_cards, :initially_activated
  end
end
