class ValidateMakeExpirationAtNotNullOnCardGrants < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :card_grants, name: "card_grants_expiration_at_null"
    change_column_null :card_grants, :expiration_at, false
    remove_check_constraint :card_grants, name: "card_grants_expiration_at_null"
  end

  def down
    add_check_constraint :card_grants, "expiration_at IS NOT NULL", name: "card_grants_expiration_at_null", validate: false
    change_column_null :card_grants, :expiration_at, true
  end
end
