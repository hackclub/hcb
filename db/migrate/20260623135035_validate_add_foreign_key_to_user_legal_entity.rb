class ValidateAddForeignKeyToUserLegalEntity < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :users, :legal_entities
  end
end
