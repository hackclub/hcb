# frozen_string_literal: true

class CreateTransferRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :transfer_records do |t|
      t.references :transferable, polymorphic: true, null: false, index: true
      t.references :event, null: false, foreign_key: true, index: true
      t.string :recipient_name
      t.string :recipient_email
      t.integer :status, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.datetime :created_at, null: false

      t.index [:event_id, :status]
      t.index [:event_id, :created_at]
    end
  end
end

