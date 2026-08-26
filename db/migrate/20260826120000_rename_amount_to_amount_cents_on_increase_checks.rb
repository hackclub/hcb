# frozen_string_literal: true

class RenameAmountToAmountCentsOnIncreaseChecks < ActiveRecord::Migration[8.1]
  def change
    rename_column :increase_checks, :amount, :amount_cents
  end

end
