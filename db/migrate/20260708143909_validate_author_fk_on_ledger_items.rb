# frozen_string_literal: true

class ValidateAuthorFkOnLedgerItems < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :ledger_items, :users, column: :author_id
  end

end
