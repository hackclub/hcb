# frozen_string_literal: true

class AddDeletedAtToAnnouncementBlocks < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :announcement_blocks, :deleted_at, :datetime
    add_index :announcement_blocks, :deleted_at, algorithm: :concurrently
  end
end
