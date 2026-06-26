class RenameLegalEntityToIlegalEntity < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      rename_table :legal_entities, :ilegal_entities
    end
  end
end
