class MakeExpirationAtNotNullOnCardGrants < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :card_grants, "expiration_at IS NOT NULL", name: "card_grants_expiration_at_null", validate: false
  end
end
