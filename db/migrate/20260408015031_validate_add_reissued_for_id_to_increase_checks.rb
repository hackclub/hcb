class ValidateAddReissuedForIdToIncreaseChecks < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :increase_checks, :increase_checks
  end
end
