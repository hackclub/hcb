# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::ReimbursementReviewerOptOut, type: :model do
  it "only lets managers opt out" do
    member_position = create(:organizer_position, role: :member)

    expect(described_class.new(organizer_position: member_position)).not_to be_valid
  end

  it "covers the sub-organizations the position gives access to" do
    parent = create(:event)
    child = create(:event, parent:)
    parent_manager = create(:user)
    child_manager = create(:user)
    parent_position = create(:organizer_position, user: parent_manager, event: parent, role: :manager)
    create(:organizer_position, user: child_manager, event: child, role: :manager)

    expect(child.reimbursement_reviewers).to contain_exactly(parent_manager, child_manager)
    expect(child.inherited_reimbursement_reviewers).to contain_exactly(parent_manager)

    parent_position.create_reimbursement_reviewer_opt_out!

    expect(parent.reimbursement_reviewers).to be_empty
    expect(child.reimbursement_reviewers).to contain_exactly(child_manager)
    expect(child.inherited_reimbursement_reviewers).to be_empty
  end

  it "is only toggled from the settings of the position's own organization" do
    parent = create(:event)
    child = create(:event, parent:)
    parent_position = create(:organizer_position, event: parent, role: :manager)
    child_position = create(:organizer_position, event: child, role: :manager)

    expect(child.reimbursement_reviewer_position_ids).to contain_exactly(child_position.id)

    child.reimbursement_reviewer_position_ids = [""]

    expect(child_position.reload.reimbursement_reviewer_opt_out).to be_present
    expect(parent_position.reload.reimbursement_reviewer_opt_out).to be_nil
    expect(child.reimbursement_reviewers).to contain_exactly(parent_position.user)
  end
end
