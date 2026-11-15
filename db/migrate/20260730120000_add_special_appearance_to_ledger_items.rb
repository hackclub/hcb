# frozen_string_literal: true

class AddSpecialAppearanceToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_items, :special_appearance, :string
  end

end
