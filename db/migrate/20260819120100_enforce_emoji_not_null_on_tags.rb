# frozen_string_literal: true

class EnforceEmojiNotNullOnTags < ActiveRecord::Migration[8.1]
  def up
    # tags_emoji_null is already validated, so this sets the column's real
    # NOT NULL without a second full-table scan. Once the column itself
    # enforces it, the check constraint is redundant.
    change_column_null :tags, :emoji, false
    remove_check_constraint :tags, name: "tags_emoji_null"
  end

  def down
    add_check_constraint :tags, "emoji IS NOT NULL", name: "tags_emoji_null", validate: false
    validate_check_constraint :tags, name: "tags_emoji_null"
    change_column_null :tags, :emoji, true
  end

end
