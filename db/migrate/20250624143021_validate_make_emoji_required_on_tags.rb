# frozen_string_literal: true

class ValidateMakeEmojiRequiredOnTags < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :tags, name: "tags_emoji_null"
  end
end
