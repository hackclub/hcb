class AddAddressToWire < ActiveRecord::Migration[7.2]
  def change
    add_column :wires, :address_city, :string
    add_column :wires, :address_line1, :string
    add_column :wires, :address_line2, :string
    add_column :wires, :address_state, :string
    add_column :wires, :address_postal_code, :string
  end
end
