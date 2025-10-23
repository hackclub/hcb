class CreateOrganizerPositionSpendingControls < ActiveRecord::Migration[7.0]
  def change
    create_table :organizer_position_spending_controls do |t|
      t.boolean :active, default: true
      t.datetime :ended_at
      t.belongs_to :organizer_position, null: false, foreign_key: true, index: { name: "idx_org_pos_spend_ctrls_on_org_pos_id"}

      t.timestamps
    end
  end
end
