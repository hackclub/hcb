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

  describe ".role_at_least?" do
    let(:event) { create(:event) }
    let(:member) { create(:organizer_position, event:, role: :member).user }

    it "keeps access during the two-factor grace period" do
      require_two_factor_authentication!(event, at: 1.day.ago)

      expect(described_class.role_at_least?(member, event, :member)).to eq(true)
    end

    it "shuts out members who ran out their two-factor grace period" do
      require_two_factor_authentication!(event, at: 8.days.ago)

      expect(described_class.role_at_least?(member, event, :reader)).to eq(false)
      expect(described_class.role_at_least?(member, event, :member)).to eq(false)
    end

    it "keeps access for members who use two-factor authentication" do
      member = create(:organizer_position, event:, role: :member, user: create(:user, :with_two_factor_authentication)).user
      require_two_factor_authentication!(event, at: 8.days.ago)

      expect(described_class.role_at_least?(member, event, :member)).to eq(true)
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
