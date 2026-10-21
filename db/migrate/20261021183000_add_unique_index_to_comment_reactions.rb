# frozen_string_literal: true

class AddUniqueIndexToCommentReactions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :comment_reactions, [:comment_id, :reactor_id, :emoji],
              unique: true,
              where: "deleted_at IS NULL",
              name: "index_comment_reactions_unique_live_reaction",
              algorithm: :concurrently
  end

  def down
    remove_index :comment_reactions, name: "index_comment_reactions_unique_live_reaction", algorithm: :concurrently
  end

end
