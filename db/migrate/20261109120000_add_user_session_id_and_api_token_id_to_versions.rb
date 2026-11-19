# frozen_string_literal: true

class AddUserSessionIdAndApiTokenIdToVersions < ActiveRecord::Migration[8.1]
  def change
    change_table :versions, bulk: true do |t|
      t.column :user_session_id, :bigint
      t.column :api_token_id, :bigint
    end
  end

end
