# frozen_string_literal: true

class RemoveHcbCodeFromDonationsAndInvoices < ActiveRecord::Migration[8.1]
  def change
    # Both columns were added in March 2021 to hold a stored HCB code, but the
    # code has been derived from the record's id since two weeks later and
    # neither column was ever written. Both models already ignore them.
    safety_assured do
      remove_column :donations, :hcb_code, :text
      remove_column :invoices, :hcb_code, :text
    end
  end

end
