# frozen_string_literal: true

class AddLegalEntityPayoutMethodToReimbursementReports < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :reimbursement_reports, :legal_entity_payout_method, index: { algorithm: :concurrently }

    add_foreign_key :reimbursement_reports, :legal_entity_payout_methods,
                    column: :legal_entity_payout_method_id, on_delete: :nullify, validate: false
  end

end
