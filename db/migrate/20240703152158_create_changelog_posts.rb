class CreateChangelogPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :changelog_posts do |t|
      t.string :title
      t.integer :headway_id
      t.string :markdown
      t.datetime :published_at

      t.timestamps
    end
  end
end
