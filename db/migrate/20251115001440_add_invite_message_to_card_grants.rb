class AddInviteMessageToCardGrants < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grants, :invite_message, :string
  end
end
