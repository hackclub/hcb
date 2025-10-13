class AddCashWithdrawalEnabledToStripeCard < ActiveRecord::Migration[7.2]
  def change
    add_column :stripe_cards, :cash_withdrawal_enabled, :boolean, default: false
  end
end
