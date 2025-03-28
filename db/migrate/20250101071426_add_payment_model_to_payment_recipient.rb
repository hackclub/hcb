class AddPaymentModelToPaymentRecipient < ActiveRecord::Migration[7.2]
  def change
    add_column :payment_recipients, :payment_model, :string
  end
end
