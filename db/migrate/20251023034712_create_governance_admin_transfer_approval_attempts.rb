class CreateGovernanceAdminTransferApprovalAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :governance_admin_transfer_approval_attempts do |t|
      t.references :governance_admin_transfer_limit, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :transfer, polymorphic: true, null: false

      t.integer :attempted_amount_cents, null: false
      t.string :result, null: false
      t.string :denial_reason

      # Snapshot of the limit right before the attempt
      t.datetime :current_limit_window_started_at, null: false
      t.datetime :current_limit_window_ended_at, null: false
      t.integer :current_limit_amount_cents, null: false
      t.integer :current_limit_used_amount_cents, null: false
      t.integer :current_limit_remaining_amount_cents, null: false

      t.timestamps
    end
  end
end
