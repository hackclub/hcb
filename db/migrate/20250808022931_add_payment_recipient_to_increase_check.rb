class AddPaymentRecipientToIncreaseCheck < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_reference :increase_checks, :payment_recipient, null: true, index: { algorithm: :concurrently }
  end
end
