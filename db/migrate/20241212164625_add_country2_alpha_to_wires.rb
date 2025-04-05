class AddCountry2AlphaToWires < ActiveRecord::Migration[7.2]
  def change
    add_column :wires, :country_alpha2, :string
  end
end
