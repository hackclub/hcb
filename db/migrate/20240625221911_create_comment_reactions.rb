class CreateCommentReactions < ActiveRecord::Migration[7.1]
  def change
    create_table :comment_reactions do |t|
      t.string :emoji, null: false
      t.references :reactor, null: false, foreign_key: { to_table: :users }
      t.references :comment, null: false, foreign_key: { to_table: :comments, column: :comment_id }

      t.index :emoji

      t.timestamps
    end
  end
end
