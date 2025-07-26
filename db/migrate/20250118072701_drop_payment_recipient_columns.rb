class DropPaymentRecipientColumns < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :payment_recipients, :account_number_ciphertext
      remove_column :payment_recipients, :bank_name_ciphertext
      remove_column :payment_recipients, :routing_number_ciphertext
    end
  end
end
