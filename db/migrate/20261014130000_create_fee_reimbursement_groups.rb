# frozen_string_literal: true

class CreateFeeReimbursementGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :fee_reimbursement_groups do |t|
      # ISO week-numbering year and week ("%G_%V"), e.g. "2026_42"
      t.string :week, null: false

      t.timestamps

      t.index :week, unique: true
    end
  end

end
