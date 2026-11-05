# frozen_string_literal: true

class AddUetrToWires < ActiveRecord::Migration[8.1]
  def change
    add_column :wires, :uetr, :string
  end

end
