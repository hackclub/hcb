class DropAchPaymentTables < ActiveRecord::Migration[7.2]
  def change
    drop_table :ach_payments
    drop_table :stripe_ach_payment_sources
  end
end
