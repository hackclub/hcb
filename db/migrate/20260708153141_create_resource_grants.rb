class CreateResourceGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :resource_grants do |t|
      t.references :owner, polymorphic: true, null: false

      t.string :resource_type, null: false
      t.string :access_level, null: false

      t.string :scope_root_type
      t.bigint :scope_root_id

      t.timestamps
    end

    add_index :resource_grants,
              [:owner_type, :owner_id, :resource_type],
              name: "index_resource_grants_on_owner_and_resource_type"
    add_index :resource_grants, [:scope_root_type, :scope_root_id]
  end
end
