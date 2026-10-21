# frozen_string_literal: true

# A user may have at most one live reaction per emoji on a comment. The model
# validation checks that with a separate SELECT, which overlapping requests can
# both get past (hackclub/hcb#15016), so make the database enforce it as well.
# Soft-deleted rows are excluded so a removed reaction can be added again.
class AddUniqueIndexToCommentReactions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    duplicate_groups = select_value(<<~SQL.squish)
      SELECT COUNT(*) FROM (
        SELECT 1 FROM comment_reactions
        WHERE deleted_at IS NULL
        GROUP BY comment_id, reactor_id, emoji
        HAVING COUNT(*) > 1
      ) duplicates
    SQL

    if duplicate_groups.positive?
      raise "comment_reactions still has #{duplicate_groups} group(s) of duplicate live reactions; " \
            "run Maintenance::RemoveDuplicateCommentReactionsTask before adding the unique index"
    end

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
