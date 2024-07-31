class AddReviewerToReimbursementReport < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    add_reference :reimbursement_reports, :reviewer, null: true, index: { algorithm: :concurrently }
  end
end
