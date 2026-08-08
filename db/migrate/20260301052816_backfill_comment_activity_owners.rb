class BackfillCommentActivityOwners < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<~SQL
      UPDATE activities
      SET owner_id = comments.user_id,
          owner_type = 'User'
      FROM comments
      WHERE activities.trackable_type = 'Comment'
        AND activities.trackable_id = comments.id
        AND activities.owner_id IS NULL
        AND comments.user_id IS NOT NULL
      SQL
    end
  end

  def down
    # nothing! we can't determine which owners were originally nil vs intentionally set, so we won't attempt to reverse this.
  end
end
