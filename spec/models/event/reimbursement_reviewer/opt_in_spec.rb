# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::ReimbursementReviewer::OptIn, type: :model do
  it "requires a manager of the organization or of one of its parents" do
    parent = create(:event)
    event = create(:event, parent:)
    member_position = create(:organizer_position, event:, role: :member)
    parent_position = create(:organizer_position, event: parent, role: :manager)
    unrelated_position = create(:organizer_position, role: :manager)

    expect(described_class.new(organizer_position: member_position, event:)).not_to be_valid
    expect(described_class.new(organizer_position: unrelated_position, event:)).not_to be_valid
    expect(described_class.new(organizer_position: parent_position, event:)).to be_valid
  end

  it "makes parent organization managers reviewers only where they opted in" do
    parent = create(:event)
    child = create(:event, parent:)
    sibling = create(:event, parent:)
    parent_position = create(:organizer_position, event: parent, role: :manager)
    child_position = create(:organizer_position, event: child, role: :manager)

    expect(parent.reimbursement_reviewers).to contain_exactly(parent_position.user)
    expect(child.reimbursement_reviewers).to contain_exactly(child_position.user)
    expect(child.reimbursement_reviewer_candidates).to contain_exactly(child_position, parent_position)

    parent_position.reimbursement_reviewer_opt_ins.create!(event: child)

    expect(child.reimbursement_reviewers).to contain_exactly(child_position.user, parent_position.user)
    expect(sibling.reimbursement_reviewers).to be_empty
  end

  it "is only toggled by the parent organization manager themselves" do
    parent = create(:event)
    child = create(:event, parent:)
    parent_position = create(:organizer_position, event: parent, role: :manager)
    child_position = create(:organizer_position, event: child, role: :manager)

    expect(child.reimbursement_reviewer_candidates_toggleable_by(child_position.user)).to contain_exactly(child_position)
    expect(child.reimbursement_reviewer_candidates_toggleable_by(parent_position.user)).to contain_exactly(child_position, parent_position)
  end

  it "doesn't leave nobody reviewing when the only submitted ids can't be toggled" do
    parent = create(:event)
    child = create(:event, parent:)
    parent_position = create(:organizer_position, event: parent, role: :manager)
    child_position = create(:organizer_position, event: child, role: :manager)
    toggleable = child.reimbursement_reviewer_candidates_toggleable_by(child_position.user)

    expect(child.update_reimbursement_reviewers(toggleable, ["", parent_position.id.to_s])).to be(false)
    expect(child.errors.full_messages).to eq(["Select at least one reviewer"])
    expect(child.reimbursement_reviewers).to contain_exactly(child_position.user)
  end
end
