# frozen_string_literal: true

class DropInitialLoginIdFromLogins < ActiveRecord::Migration[7.2]
  def change
    # The column is ignored and all references have been removed
    safety_assured do
      remove_reference(:logins, :initial_login, index: false)
    end
  end
end

