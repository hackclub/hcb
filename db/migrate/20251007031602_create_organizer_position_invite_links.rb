class CreateOrganizerPositionInviteLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :organizer_position_invite_links do |t|
      t.references :event, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.datetime :deactivated_at
      t.references :deactivator, foreign_key: { to_table: :users }
      t.integer :expires_in, null: false, default: 60 * 60 * 24 * 30

      t.timestamps
    end
  end
end
