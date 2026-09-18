# frozen_string_literal: true

class AddMerchantIndexesToCardCharges < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :card_charges, :merchant_network_id, algorithm: :concurrently
    add_index :card_charges, :merchant_category, algorithm: :concurrently
  end

end
