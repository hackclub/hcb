# frozen_string_literal: true

class MakeEmojiRequiredOnTags < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :tags, "emoji IS NOT NULL", name: "tags_emoji_null", validate: false
  end
end
