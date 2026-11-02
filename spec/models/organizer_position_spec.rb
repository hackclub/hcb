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
      # Keep another manager around so `position` can be demoted again
      create(:organizer_position, event: position.event, role: :manager)

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

    it "are kept when a manager is promoted to owner" do
      position = create(:organizer_position, role: :manager)

      promote_to_owner(position)

      expect(position.reimbursement_reviewer_opt_ins.reload.map(&:event)).to eq([position.event])
    end
  end

  describe "at least one manager" do
    let(:event) { create(:event) }

    it "prevents demoting the last manager" do
      manager = create(:organizer_position, event:, role: :manager)

      expect(manager.update(role: :member)).to be(false)
      expect(manager.errors[:event]).to include("must have at least one manager")
    end

    it "prevents demoting the last owner" do
      owner = promote_to_owner(create(:organizer_position, event:, role: :manager))

      expect(owner.update(role: :reader)).to be(false)
    end

    it "allows demoting a manager while another manager or owner remains" do
      manager = create(:organizer_position, event:, role: :manager)
      promote_to_owner(create(:organizer_position, event:, role: :manager))

      expect(manager.update(role: :member)).to be(true)
    end

    it "allows promoting a member in an organization without managers" do
      member = create(:organizer_position, event:, role: :member)

      expect(member.update(role: :manager)).to be(true)
    end

    it "allows changing roles below manager in an organization without managers" do
      member = create(:organizer_position, event:, role: :member)

      expect(member.update(role: :reader)).to be(true)
    end
  end

  describe ".role_at_least?" do
    let(:parent) { create(:event) }
    let(:event) { create(:event, parent:) }

    it "treats owners as managers" do
      owner = promote_to_owner(create(:organizer_position, event:, role: :manager))

      expect(described_class.role_at_least?(owner.user, event, :manager)).to be(true)
      expect(described_class.role_at_least?(owner.user, event, :owner)).to be(true)
    end

    it "does not treat managers as owners" do
      manager = create(:organizer_position, event:, role: :manager)

      expect(described_class.role_at_least?(manager.user, event, :owner)).to be(false)
    end

    it "does not inherit ownership from an ancestor" do
      parent_owner = promote_to_owner(create(:organizer_position, event: parent, role: :manager))

      expect(described_class.role_at_least?(parent_owner.user, event, :manager)).to be(true)
      expect(described_class.role_at_least?(parent_owner.user, event, :owner)).to be(false)
    end
  end

  def promote_to_owner(position)
    # Contracts add HCB as a party via the system user
    allow(User).to receive(:system_user).and_return(User.find_by(email: User::SYSTEM_USER_EMAIL) || create(:user, email: User::SYSTEM_USER_EMAIL))
    contract = Contract::FiscalSponsorship.create!(contractable: position.organizer_position_invite, include_videos: false)
    contract.update_column(:aasm_state, "signed")
    position.update!(role: :owner, fiscal_sponsorship_contract: contract)
    position
  end
end
