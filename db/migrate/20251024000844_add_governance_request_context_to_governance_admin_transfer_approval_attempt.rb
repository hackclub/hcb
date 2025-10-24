# db/migrate/20251024000844_add_governance_request_context_to_gov_admin_transfer_approval_attempts.rb
class AddGovernanceRequestContextToGovernanceAdminTransferApprovalAttempt < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # 1) Add the column + concurrent index
    add_reference :governance_admin_transfer_approval_attempts,
                  :governance_request_context,
                  null: false,
                  index: { algorithm: :concurrently }

    # 2) Add FK as NOT VALID (non-blocking)
    add_foreign_key :governance_admin_transfer_approval_attempts,
                    :governance_request_contexts,
                    column: :governance_request_context_id,
                    validate: false

    # 3) Validate FK (concurrent)
    validate_foreign_key :governance_admin_transfer_approval_attempts,
                         :governance_request_contexts
  end

  def down
    remove_foreign_key :governance_admin_transfer_approval_attempts, column: :governance_request_context_id
    remove_reference :governance_admin_transfer_approval_attempts, :governance_request_context, index: true
  end
end