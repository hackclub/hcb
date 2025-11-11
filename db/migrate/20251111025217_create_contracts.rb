class CreateContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :contracts do |t|
      t.string :aasm_state
      t.string :cosigner_email
      t.integer :external_service
      t.boolean :include_videos
      t.string :external_id

      t.datetime :signed_at
      t.datetime :void_at
      t.timestamp :deleted_at

      t.references :contractable, polymorphic: true
      t.references :document, foreign_key: true
      t.references :organizer_position, foreign_key: true

      t.timestamps
    end
  end
end
