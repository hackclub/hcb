class AddCardGrantToReimbursementReports < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :reimbursement_reports, :card_grant, null: true, index: { algorithm: :concurrently }
  end
end
