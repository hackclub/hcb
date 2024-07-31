# frozen_string_literal: true

class AddTrustedToOauthApplications < ActiveRecord::Migration[7.0]
  def change
    add_column :oauth_applications, :trusted, :boolean, default: false, null: false
  end

end
