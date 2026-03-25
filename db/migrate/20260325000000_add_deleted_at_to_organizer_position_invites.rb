# frozen_string_literal: true

class AddDeletedAtToOrganizerPositionInvites < ActiveRecord::Migration[7.2]
  def change
    add_column :organizer_position_invites, :deleted_at, :datetime
    add_index :organizer_position_invites, :deleted_at
  end
end
