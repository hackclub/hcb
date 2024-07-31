class AddTeamReviewToggleToReimbursements < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :reimbursements_require_organizer_peer_review, :boolean, default: false, null: false
  end
end
