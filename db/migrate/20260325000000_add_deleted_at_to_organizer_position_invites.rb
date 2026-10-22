# frozen_string_literal: true

class AddDeletedAtToOrganizerPositionInvites < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :organizer_position_invites, :deleted_at, :datetime
    add_index :organizer_position_invites, :deleted_at, algorithm: :concurrently
  end
end
