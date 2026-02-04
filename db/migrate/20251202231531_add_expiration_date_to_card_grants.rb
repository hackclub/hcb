class AddExpirationDateToCardGrants < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grants, :expiration_at, :datetime
  end
end
