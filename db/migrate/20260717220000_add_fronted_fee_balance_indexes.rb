# frozen_string_literal: true

class AddFrontedFeeBalanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :fees, :reason, algorithm: :concurrently

    add_index :fees, :event_id,
              include: [:amount_cents_as_decimal],
              name: "index_fees_on_event_id_include_amount",
              algorithm: :concurrently
  end

end
