# frozen_string_literal: true

# Whether a form's TIN counts as verified for payability
# (LegalEntity#pending_payable_requirements). For forms collected through
# TaxBandits it follows TaxBandits' TIN match (see Tax::Form). For Tax1099
# imports, which TaxBandits never TIN-matches, it's what the admin said when
# importing (verified unless they said otherwise). Backfilled by
# BackfillTinVerifiedOnTaxForms.
class AddTinVerifiedToTaxForms < ActiveRecord::Migration[8.1]
  def change
    add_column :tax_forms, :tin_verified, :boolean, null: false, default: false
  end

end
