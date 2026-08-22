# frozen_string_literal: true

class AddGinIndexForLedgerItemMemoSearch < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Expression must match exactly what Ledger::Item's pg_search_scope(:search_memo)
    # generates (dictionary "simple") for Postgres to use this index for that search.
    add_index :ledger_items, "to_tsvector('simple', coalesce(memo, ''))",
              using: :gin,
              name: "index_ledger_items_on_memo_tsvector",
              algorithm: :concurrently
  end

end
