class AddSendInstructionsToWire < ActiveRecord::Migration[7.1]
  def change
    add_column :wires, :recipient_country, :integer
    add_column :wires, :recipient_information, :jsonb # this is a jsonb because there are so many damm fields! and they vary by country / currency.
  end
end
