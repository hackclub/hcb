class AddNameToLegalEntities < ActiveRecord::Migration[8.0]
  def change
    add_column :legal_entities, :name, :string
  end
end
