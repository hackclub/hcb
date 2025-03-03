class AddCanceledAtToStripeCards < ActiveRecord::Migration[7.2]
  def change
    add_column :stripe_cards, :canceled_at, :datetime
  end
end
