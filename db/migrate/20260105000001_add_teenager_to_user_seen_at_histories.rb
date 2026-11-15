# frozen_string_literal: true

class AddTeenagerToUserSeenAtHistories < ActiveRecord::Migration[8.0]
  def change
    add_column :user_seen_at_histories, :teenager, :boolean
  end
end
