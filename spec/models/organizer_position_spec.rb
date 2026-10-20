# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPosition, type: :model do
  let(:organizer_position) { create(:organizer_position) }

  it "is valid" do
    expect(organizer_position).to be_valid
  end

  context "missing user" do
    before do
      organizer_position.user = nil
    end

    it "is not valid" do
      expect(organizer_position).to_not be_valid
    end
  end

  context "missing event" do
    before do
      organizer_position.event = nil
    end

    it "is not valid" do
      expect(organizer_position).to_not be_valid
    end
  end

  describe "losing manager access" do
    it "clears reimbursement reviewer opt-outs on organizations they no longer manage" do
      parent = create(:event)
      child = create(:event, parent:)
      parent_manager = create(:user)
      dual_manager = create(:user)
      parent_position = create(:organizer_position, user: parent_manager, event: parent, role: :manager)
      dual_parent_position = create(:organizer_position, user: dual_manager, event: parent, role: :manager)
      create(:organizer_position, user: dual_manager, event: child, role: :manager)
      child.reimbursement_reviewer_opt_outs.create!(user: parent_manager)
      child.reimbursement_reviewer_opt_outs.create!(user: dual_manager)

      parent_position.update!(role: :member)
      dual_parent_position.destroy!

      expect(child.reimbursement_reviewer_opt_outs.map(&:user)).to contain_exactly(dual_manager)
    end
  end
end
