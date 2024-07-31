# frozen_string_literal: true

class AddColumnIdToCheckDeposits < ActiveRecord::Migration[7.1]
  def change
    add_column :check_deposits, :column_id, :string
  end

end
