# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contract, type: :model do
  describe "#mark_voided! archival behavior" do
    let(:payee) { create(:payee) }
    let(:position) { create(:payroll_position, payee:) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    it "does not contact DocuSeal for a contract that was never sent" do
      contract = Contract::PayrollPosition.create!(contractable: position, include_videos: false)

      expect { contract.mark_voided!(reissuing: true) }.not_to raise_error
      expect(contract).to be_voided
    end

  end

  describe "#owned_by?" do
    let(:payee) { create(:payee) }
    let(:position) { create(:payroll_position, payee:) }
    let(:organizer) { create(:user) }
    let(:other_user) { create(:user) }

    let!(:contract) do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

      Contract::PayrollPosition.create!(contractable: position, include_videos: false).tap do |c|
        c.parties.create!(user: organizer, role: :organizer)
        c.parties.create!(external_email: payee.email, role: :contractor)
      end
    end

    it "is true for the contract's signee/organizer party" do
      expect(contract.owned_by?(organizer)).to eq(true)
    end

    it "is false for an unrelated user" do
      expect(contract.owned_by?(other_user)).to eq(false)
    end

    it "is false for nil" do
      expect(contract.owned_by?(nil)).to eq(false)
    end
  end
end
