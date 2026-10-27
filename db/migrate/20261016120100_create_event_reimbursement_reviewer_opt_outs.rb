# frozen_string_literal: true

class CreateEventReimbursementReviewerOptOuts < ActiveRecord::Migration[8.1]
  def change
    create_table :event_reimbursement_reviewer_opt_outs do |t|
      t.references :organizer_position, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end

end
