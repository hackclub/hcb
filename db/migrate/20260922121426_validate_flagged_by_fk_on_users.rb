# frozen_string_literal: true

class ValidateFlaggedByFkOnUsers < ActiveRecord::Migration[8.1]
  def up
    validate_foreign_key :users, column: :flagged_by_id
  end

  def down
  end

end
