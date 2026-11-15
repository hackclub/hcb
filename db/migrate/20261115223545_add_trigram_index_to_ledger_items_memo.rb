# frozen_string_literal: true

# Serves Ledger::Item.search_memo, which matches each search word anywhere in
# a memo (`memo ILIKE '%word%'`).
class AddTrigramIndexToLedgerItemsMemo < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_ledger_items_on_memo_trgm"

  def up
    # A concurrent build waits for every older transaction to finish, and
    # strong_migrations' 10s lock_timeout would cancel it on any long one.
    with_lock_timeout("10min") do
      # A cancelled concurrent build leaves an invalid index holding the name,
      # which `if_not_exists` alone would silently skip.
      remove_index :ledger_items, name: INDEX_NAME, if_exists: true, algorithm: :concurrently if index&.valid == false

      add_index :ledger_items, :memo, using: :gin, opclass: :gin_trgm_ops, name: INDEX_NAME, if_not_exists: true, algorithm: :concurrently
    end

    raise "#{INDEX_NAME} is missing or invalid" unless index&.valid
  end

  def down
    remove_index :ledger_items, name: INDEX_NAME, if_exists: true, algorithm: :concurrently
  end

  private

  def index
    connection.indexes(:ledger_items).find { |index| index.name == INDEX_NAME }
  end

  def with_lock_timeout(timeout)
    previous = select_value("SHOW lock_timeout")
    safety_assured { execute("SET lock_timeout = #{connection.quote(timeout)}") }
    yield
  ensure
    safety_assured { execute("SET lock_timeout = #{connection.quote(previous)}") } if previous
  end

end
