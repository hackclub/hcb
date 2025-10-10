class CreateOrganizerPositionInviteRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :organizer_position_invite_requests do |t|
      t.references :organizer_position_invite_link, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.string :aasm_state, null: false

      t.timestamps
    end
  end
end
