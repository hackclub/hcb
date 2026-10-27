# frozen_string_literal: true

class AddReimbursementReviewerSelectionToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :reimbursement_reviewer_selection, :string, default: "disabled", null: false

    # Hack Club affiliates always required a reviewer before this was a setting
    safety_assured do
      execute <<~SQL.squish
        UPDATE events SET reimbursement_reviewer_selection = 'required'
        WHERE id IN (SELECT event_id FROM event_plans WHERE type = 'Event::Plan::HackClubAffiliate' AND aasm_state = 'active')
      SQL
    end
  end

  def down
    remove_column :events, :reimbursement_reviewer_selection
  end

end
