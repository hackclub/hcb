class AddSigningUrlToTaxForms < ActiveRecord::Migration[8.0]
  def change
    add_column :tax_forms, :signing_url, :string
    add_column :tax_forms, :document_url, :string
  end
end
