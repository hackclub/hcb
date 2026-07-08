class CreateDoorkeeperApplicationResourceGrantTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :doorkeeper_application_resource_grant_templates do |t|
      t.belongs_to :application, null: false, foreign_key: { to_table: :oauth_applications }

      t.string :resource_type, null: false
      t.string :access_level, null: false

      t.string :scope_root_type
      t.bigint :scope_root_id

      t.timestamps
    end
  end
end
