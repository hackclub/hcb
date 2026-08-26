# frozen_string_literal: true

class RenameAmountToAmountCentsOnAchTransfers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :ach_transfers, :amount, :amount_cents
    end
  end

end
