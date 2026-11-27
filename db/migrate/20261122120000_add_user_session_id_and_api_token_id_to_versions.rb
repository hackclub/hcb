# frozen_string_literal: true

class AddUserSessionIdAndApiTokenIdToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :user_session_id, :bigint
    add_column :versions, :api_token_id, :bigint
  end

end
