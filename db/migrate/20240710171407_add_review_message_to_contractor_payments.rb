class AddReviewMessageToContractorPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :employee_payments, :review_message, :text
  end
end
