# frozen_string_literal: true

class AddInitialLoginIdToLogins < ActiveRecord::Migration[7.2]
  def change
    add_reference(:logins, :initial_login, index: false)
  end
end
