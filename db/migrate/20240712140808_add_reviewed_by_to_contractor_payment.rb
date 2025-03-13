class AddReviewedByToContractorPayment < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    add_reference :employee_payments, :reviewed_by, null: true, index: { algorithm: :concurrently }
  end
end
