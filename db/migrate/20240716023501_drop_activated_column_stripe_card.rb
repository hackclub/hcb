class DropActivatedColumnStripeCard < ActiveRecord::Migration[7.1]
    def up
      safety_assured { remove_column :stripe_cards, :activated, :boolean }
    end
    def down
      add_column :stripe_cards, :activated, :boolean, default: false
    end
end
