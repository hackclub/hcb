# frozen_string_literal: true

class CreateEventReimbursementReviewers < ActiveRecord::Migration[8.1]
  def change
    create_table :event_reimbursement_reviewers do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_reimbursement_reviewers, [:event_id, :user_id], unique: true
  end

end
