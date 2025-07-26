class AddEmojiToTags < ActiveRecord::Migration[7.2]
  def change
    add_column :tags, :emoji, :string
  end
end
