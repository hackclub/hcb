# frozen_string_literal: true

class AddDeletedAtToAnnouncementBlocks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :announcement_blocks, :deleted_at, :datetime
    add_index :announcement_blocks, :deleted_at, algorithm: :concurrently
  end
end
