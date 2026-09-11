# frozen_string_literal: true

class AddIdempotencyKeyToDisbursements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :disbursements, :idempotency_key, :string
    add_index :disbursements, [:source_event_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL", algorithm: :concurrently
  end

end
