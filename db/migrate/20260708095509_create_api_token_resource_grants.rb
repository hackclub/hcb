class CreateApiTokenResourceGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :api_token_resource_grants do |t|
      t.belongs_to :api_token, null: false, foreign_key: true

      t.string :resource_type, null: false
      t.string :access_level, null: false

      t.string :scope_root_type
      t.bigint :scope_root_id

      t.timestamps
    end

    add_index :api_token_resource_grants,
              [:api_token_id, :resource_type, :access_level],
              name: "index_api_token_resource_grants_on_token_and_type_and_level"
    add_index :api_token_resource_grants, [:scope_root_type, :scope_root_id]
  end
end
