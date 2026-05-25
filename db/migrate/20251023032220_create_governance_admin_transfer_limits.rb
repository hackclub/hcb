class CreateGovernanceAdminTransferLimits < ActiveRecord::Migration[7.2]
  def change
    create_table :governance_admin_transfer_limits do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :amount_cents, null: false

      t.timestamps
    end

    add_index :governance_admin_transfer_limits, :user_id, unique: true
  end
end
