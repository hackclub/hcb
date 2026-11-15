class ChangeStripeTopupIdColumnType < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    remove_index :stripe_service_fees, name: :index_stripe_service_fees_on_stripe_topup_id
    safety_assured do
      remove_column :stripe_service_fees, :stripe_topup_id 
    end
    add_reference :stripe_service_fees, :stripe_topup, index: {algorithm: :concurrently}
  end
end
