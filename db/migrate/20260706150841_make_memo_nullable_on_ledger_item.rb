class MakeMemoNullableOnLedgerItem < ActiveRecord::Migration[8.0]
  def change
    change_column_null :ledger_items, :memo, true
  end
end
