class CreateOrganizerPositionContract < ActiveRecord::Migration[7.1]
  def change
    create_table :organizer_position_contracts do |t|
      t.belongs_to :document, null: true
      t.belongs_to :organizer_position_invite, null: false

      t.string :aasm_state

      t.datetime :signed_at
      t.datetime :void_at
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
