# frozen_string_literal: true

class CreateLostReceiptFilings < ActiveRecord::Migration[8.1]
  def change
    create_table :lost_receipt_filings do |t|
      t.references :receipt, null: false, foreign_key: true, index: { unique: true }
      t.references :event, foreign_key: true
      # The cardholder. Null for ACHs, checks, and anything else we can't pin on one person.
      t.references :user, foreign_key: true

      t.timestamps
    end
  end

end
