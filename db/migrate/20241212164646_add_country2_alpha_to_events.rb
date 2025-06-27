class AddCountry2AlphaToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :country_alpha2, :string
  end
end
