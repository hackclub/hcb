# frozen_string_literal: true

class AddReimbursementReviewerSelectionToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :reimbursement_reviewer_selection, :integer, default: 0, null: false
  end

end
