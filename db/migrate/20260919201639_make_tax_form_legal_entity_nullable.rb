class MakeTaxFormLegalEntityNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :tax_forms, :legal_entity_id, true
  end
end
