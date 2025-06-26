class CreateBlogPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :blog_posts do |t|
      t.string :slug
      t.string :title
      t.string :tags
      t.string :preview
      t.datetime :published_at

      t.timestamps
    end
  end
end
