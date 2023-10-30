# frozen_string_literal: true

class AddAccessLevelToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :access_level, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        User.update_all("access_level = CASE WHEN admin_at IS NOT NULL THEN 1 ELSE 0 END")
      end
    end
  end

end
