class AddPaymentRecipientToWire < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_reference :wires, :payment_recipient, null: true, index: { algorithm: :concurrently }
  end
end
