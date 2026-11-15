class AddSourceToTaxForm < ActiveRecord::Migration[8.1]
  def change
    add_column :tax_forms, :source, :string, null: false, default: :taxbandits
  end
end
