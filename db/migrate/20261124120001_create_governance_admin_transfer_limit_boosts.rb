# frozen_string_literal: true

class CreateGovernanceAdminTransferLimitBoosts < ActiveRecord::Migration[8.1]
  def change
    create_table :governance_admin_transfer_limit_boosts do |t|
      t.references :governance_admin_transfer_limit, null: false, foreign_key: true
      t.references :granted_by, null: false, foreign_key: { to_table: :users }

      t.integer :amount_cents, null: false
      t.datetime :expires_at, null: false
      t.text :reason, null: false

      t.timestamps
    end

    add_column :governance_admin_transfer_approval_attempts, :current_limit_boost_amount_cents, :integer, null: false, default: 0
  end

end
