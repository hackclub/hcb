# frozen_string_literal: true

class AddDeletedAtToCommentReactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :comment_reactions, :deleted_at, :datetime
    add_index :comment_reactions, :deleted_at, algorithm: :concurrently
  end
end
