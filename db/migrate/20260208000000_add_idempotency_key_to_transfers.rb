# frozen_string_literal: true

class AddIdempotencyKeyToTransfers < ActiveRecord::Migration[7.2]
  def change
    add_column :disbursements, :idempotency_key, :string
    add_column :ach_transfers, :idempotency_key, :string
    add_column :wise_transfers, :idempotency_key, :string
    add_column :wires, :idempotency_key, :string

    add_index :disbursements, :idempotency_key, unique: true
    add_index :ach_transfers, :idempotency_key, unique: true
    add_index :wise_transfers, :idempotency_key, unique: true
    add_index :wires, :idempotency_key, unique: true
  end
end
