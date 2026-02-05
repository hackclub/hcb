class AddBlockSuspectedFraudToCardGrantSetting < ActiveRecord::Migration[8.0]
  def change
    add_column :card_grant_settings, :block_suspected_fraud, :boolean, null: false, default: true
  end
end
