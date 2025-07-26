class AddInformationToPaymentRecipient < ActiveRecord::Migration[7.2]
  def change
    add_column :payment_recipients, :information_ciphertext, :text
  end
end
