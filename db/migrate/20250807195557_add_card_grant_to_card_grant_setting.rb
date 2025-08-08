class AddCardGrantToCardGrantSetting < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_reference :card_grant_settings, :card_grant, index: {algorithm: :concurrently}
  end

  def down
    remove_reference :card_grant_settings, :card_grant, index: {algorithm: :concurrently}
  end
end
