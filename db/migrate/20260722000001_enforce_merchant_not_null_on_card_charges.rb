# frozen_string_literal: true

class EnforceMerchantNotNullOnCardCharges < ActiveRecord::Migration[8.0]
  # Runs outside a transaction so each validation isn't left holding locks that
  # block writes while the next operation runs.
  disable_ddl_transaction!

  def up
    # Validating the check constraints lets Postgres set NOT NULL on the columns
    # without a second full scan.
    validate_check_constraint :card_charges, name: "card_charges_merchant_category_null"
    change_column_null :card_charges, :merchant_category, false
    remove_check_constraint :card_charges, name: "card_charges_merchant_category_null"

    validate_check_constraint :card_charges, name: "card_charges_merchant_network_id_null"
    change_column_null :card_charges, :merchant_network_id, false
    remove_check_constraint :card_charges, name: "card_charges_merchant_network_id_null"
  end

  def down
    add_check_constraint :card_charges, "merchant_category IS NOT NULL", name: "card_charges_merchant_category_null", validate: false
    change_column_null :card_charges, :merchant_category, true

    add_check_constraint :card_charges, "merchant_network_id IS NOT NULL", name: "card_charges_merchant_network_id_null", validate: false
    change_column_null :card_charges, :merchant_network_id, true
  end

end
