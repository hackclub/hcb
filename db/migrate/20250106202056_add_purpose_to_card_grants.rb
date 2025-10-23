class AddPurposeToCardGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :purpose, :string
  end
end
