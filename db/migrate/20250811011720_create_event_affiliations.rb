class CreateEventAffiliations < ActiveRecord::Migration[7.2]
  def change
    create_table :event_affiliations do |t|
      t.references :event, null: false, foreign_key: true
      t.jsonb :metadata
      t.string :name

      t.timestamps
    end
  end
end
