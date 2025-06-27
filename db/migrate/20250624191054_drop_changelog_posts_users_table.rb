class DropChangelogPostsUsersTable < ActiveRecord::Migration[7.2]
  def up
    drop_table :changelog_posts_users
  end

  def down
    fail ActiveRecord::IrreversibleMigration
  end
end
