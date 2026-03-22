class AddOneTimeUseToCardGrant < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :one_time_use, :boolean
  end
end
