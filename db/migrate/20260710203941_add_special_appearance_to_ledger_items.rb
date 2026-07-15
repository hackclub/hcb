# frozen_string_literal: true

class AddSpecialAppearanceToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    add_column :ledger_items, :special_appearance, :integer
  end

end
