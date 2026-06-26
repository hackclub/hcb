class RenameIlegalEntityToIllegalEntity < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      rename_table :ilegal_entities, :illegal_entities
    end
  end
end
