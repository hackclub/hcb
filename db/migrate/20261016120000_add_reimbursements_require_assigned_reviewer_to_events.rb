# frozen_string_literal: true

class AddReimbursementsRequireAssignedReviewerToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :reimbursements_require_assigned_reviewer, :boolean, default: false, null: false
  end

end
