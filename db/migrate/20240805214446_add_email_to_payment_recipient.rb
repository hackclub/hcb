class AddEmailToPaymentRecipient < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_recipients, :email, :text
  end
end
