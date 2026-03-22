class DropChangelogPostsUsersTable < ActiveRecord::Migration[7.2]
  def up
    drop_table :changelog_posts_users
  end

  def down
    create_table :changelog_posts_users do |t|
      t.references :changelog_post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :changelog_posts_users, [:changelog_post_id, :user_id], unique: true
  end
end
