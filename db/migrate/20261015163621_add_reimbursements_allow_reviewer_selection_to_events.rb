# frozen_string_literal: true

class AddReimbursementsAllowReviewerSelectionToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :reimbursements_allow_reviewer_selection, :boolean, default: true, null: false
  end

end
