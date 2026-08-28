# frozen_string_literal: true

class AddStatusDefaultToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    # `pending` is what `Ledger::Item#calculate_status` falls back to when nothing
    # has mapped to an item yet, so a row inserted before its first refresh reads
    # the same way it will afterwards.
    change_column_default :ledger_items, :status, from: nil, to: "pending"
  end

end
