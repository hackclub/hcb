# frozen_string_literal: true

class AddFeeReimbursementGroupToFeeReimbursements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :fee_reimbursements, :fee_reimbursement_group, index: { algorithm: :concurrently }

    add_foreign_key :fee_reimbursements, :fee_reimbursement_groups, validate: false

    validate_foreign_key :fee_reimbursements, :fee_reimbursement_groups
  end

end
