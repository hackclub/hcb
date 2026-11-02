# frozen_string_literal: true

class AddAuthorToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :ledger_items, :author, index: { algorithm: :concurrently }

    add_foreign_key :ledger_items, :users, column: :author_id, validate: false
  end

end
