class AddForeignKeyToUserLegalEntity < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :users, :legal_entities, validate: false
  end
end
