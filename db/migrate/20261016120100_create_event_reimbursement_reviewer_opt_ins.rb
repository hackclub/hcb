# frozen_string_literal: true

class CreateEventReimbursementReviewerOptIns < ActiveRecord::Migration[8.1]
  def up
    create_table :event_reimbursement_reviewer_opt_ins do |t|
      t.references :organizer_position, null: false, foreign_key: true, index: false
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_reimbursement_reviewer_opt_ins, [:organizer_position_id, :event_id], unique: true

    # Every current manager reviews their own organization's reports by default
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO event_reimbursement_reviewer_opt_ins (organizer_position_id, event_id, created_at, updated_at)
        SELECT id, event_id, NOW(), NOW()
        FROM organizer_positions
        WHERE role = #{OrganizerPosition.roles[:manager]} AND deleted_at IS NULL
      SQL
    end
  end

  def down
    drop_table :event_reimbursement_reviewer_opt_ins
  end

end
