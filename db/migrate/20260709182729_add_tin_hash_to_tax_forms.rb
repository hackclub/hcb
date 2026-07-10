class AddTinHashToTaxForms < ActiveRecord::Migration[8.0]
  def change
    add_column :tax_forms, :tin_hash, :string
  end
end
