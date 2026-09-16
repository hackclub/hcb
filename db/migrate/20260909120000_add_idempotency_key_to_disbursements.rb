# frozen_string_literal: true

class AddIdempotencyKeyToDisbursements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :disbursements, :idempotency_key, :string
    add_index :disbursements, [:source_event_id, :requested_by_id, :idempotency_key], unique: true, where: "idempotency_key IS NOT NULL", name: "index_disbursements_on_idempotency_key", algorithm: :concurrently
  end

end
