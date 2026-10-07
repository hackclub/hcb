class DropLegalEntityAddressColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured {
      remove_column :legal_entities, :address_line1, :string
      remove_column :legal_entities, :address_line2, :string
      remove_column :legal_entities, :address_city, :string
      remove_column :legal_entities, :address_state, :string
      remove_column :legal_entities, :address_postal_code, :string
      remove_column :legal_entities, :address_country, :string
    }
  end
end
