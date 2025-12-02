class AddExpirationDateToCardGrants < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grants, :expiration_date, :datetime
  end
end
