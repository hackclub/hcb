class CreateEventConfiguration < ActiveRecord::Migration[7.1]
  def change
    create_table :event_configurations do |t|
      t.belongs_to :event, null: false, foreign_key: true
      t.boolean :anonymous_donations, default: false
      t.timestamps
    end
  end
end
