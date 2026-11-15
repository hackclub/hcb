# frozen_string_literal: true

class DropCanFrontBalanceFromEvents < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :events, :can_front_balance, :boolean, default: true, null: false }
  end

end
