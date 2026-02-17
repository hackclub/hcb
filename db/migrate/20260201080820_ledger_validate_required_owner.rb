class LedgerValidateRequiredOwner < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :ledgers, name: "ledgers_owner_rules"
  end
end
