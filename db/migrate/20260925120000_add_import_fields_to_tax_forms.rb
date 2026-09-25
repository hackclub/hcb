# frozen_string_literal: true

class AddImportFieldsToTaxForms < ActiveRecord::Migration[8.1]
  def change
    add_column :tax_forms, :import_email, :string
    add_column :tax_forms, :import_name, :string
    change_column_null :tax_forms, :legal_entity_id, true
  end

end
