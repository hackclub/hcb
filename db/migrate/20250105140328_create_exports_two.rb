class CreateExportsTwo < ActiveRecord::Migration[7.2]
  def change
    create_table :exports do |t|
      t.text :type
      t.jsonb :parameters
      t.references :requested_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
