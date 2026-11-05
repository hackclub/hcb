class AddTaxbanditsImportFieldsToTaxForms < ActiveRecord::Migration[8.0]
  def change
    # Derived from the TaxBandits submission at import time so that rendering a
    # page never has to re-fetch the submission (which carries the full TIN).
    add_column :tax_forms, :entity_type, :string
    add_column :tax_forms, :tin_type, :string
  end

end
