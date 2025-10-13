class DropChangelogPostsTable < ActiveRecord::Migration[7.2]
  def up
    drop_table :changelog_posts
  end

  def down
    create_table :changelog_posts do |t|
      t.string :title
      t.integer :headway_id
      t.string :markdown
      t.datetime :published_at

      t.timestamps
    end
  end
end
