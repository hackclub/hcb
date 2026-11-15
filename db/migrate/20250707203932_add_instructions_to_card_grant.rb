class AddInstructionsToCardGrant < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :instructions, :text
  end
end
