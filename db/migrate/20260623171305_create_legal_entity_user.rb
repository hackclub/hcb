class CreateLegalEntityUser < ActiveRecord::Migration[8.0]
  def change
    create_table :legal_entity_users do |t|
      t.belongs_to :legal_entity, null: false
      t.belongs_to :user, null: false

      t.timestamps
    end
  end
end
