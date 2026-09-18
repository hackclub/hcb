# frozen_string_literal: true

# Neither denormalized merchant column was indexed, so filtering a ledger by
# merchant (EventsController#ledger) sequentially scanned every card charge.
# Both are also the columns the merchant and category breakdowns group by, once
# those stop reading merchant_data out of the raw Stripe JSONB.
class AddMerchantIndexesToCardCharges < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :card_charges, :merchant_network_id, algorithm: :concurrently
    add_index :card_charges, :merchant_category, algorithm: :concurrently
  end

end
