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

  describe "reimbursement reviewer opt-ins" do
    it "follow the manager role" do
      position = create(:organizer_position, role: :member)

      expect(position.reimbursement_reviewer_opt_ins).to be_empty

      position.update!(role: :manager)

      expect(position.reimbursement_reviewer_opt_ins.reload.map(&:event)).to eq([position.event])

      position.update!(role: :member)

      expect(position.reimbursement_reviewer_opt_ins.reload).to be_empty
    end

    it "are removed along with the position" do
      position = create(:organizer_position, role: :manager)
      opt_in = position.reimbursement_reviewer_opt_ins.sole

      position.destroy!

      expect(position.reload).to be_deleted
      expect(Event::ReimbursementReviewer::OptIn.exists?(opt_in.id)).to be(false)
    end
  end
end
