# frozen_string_literal: true

class AddUserAgentToUserSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_sessions, :user_agent, :text
  end

end
