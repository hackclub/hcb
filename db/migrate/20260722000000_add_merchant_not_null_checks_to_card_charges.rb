# frozen_string_literal: true

class AddMerchantNotNullChecksToCardCharges < ActiveRecord::Migration[8.0]
  def change
    # Add the NOT NULL guards as check constraints first (NOT VALID) so they
    # don't scan/lock the table. They're validated in a later migration before
    # being promoted to real NOT NULLs on the columns.
    add_check_constraint :card_charges, "merchant_category IS NOT NULL", name: "card_charges_merchant_category_null", validate: false
    add_check_constraint :card_charges, "merchant_network_id IS NOT NULL", name: "card_charges_merchant_network_id_null", validate: false
  end

end
