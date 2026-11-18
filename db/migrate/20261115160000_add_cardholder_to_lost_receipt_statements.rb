# frozen_string_literal: true

class AddCardholderToLostReceiptStatements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Who the lost receipt counts against. Null for ACHs, checks, and anything else we can't pin on one person.
    add_reference :lost_receipt_statements, :cardholder, index: { algorithm: :concurrently }
    add_foreign_key :lost_receipt_statements, :users, column: :cardholder_id, validate: false
    validate_foreign_key :lost_receipt_statements, :users, column: :cardholder_id
  end

end
