class CreateLegalEntityPayoutMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :legal_entity_payout_methods do |t|
      t.belongs_to :legal_entity, null: false
      t.belongs_to :details, polymorphic: true, null: false
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    # at most one default payout method per legal entity
    add_index :legal_entity_payout_methods,
              :legal_entity_id,
              unique: true,
              where: "\"default\" = true",
              name: "index_le_payout_methods_one_default_per_entity"
  end
end
