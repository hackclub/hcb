# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contract::PartyPolicy, type: :policy do
  let(:payee) { create(:payee) }
  let(:position) { create(:payroll_position, payee:) }
  let(:organizer) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :make_admin) }

  let!(:contract) do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

    Contract::PayrollPosition.create!(contractable: position, include_videos: false).tap do |c|
      c.parties.create!(user: organizer, role: :organizer)
      c.parties.create!(external_email: payee.email, role: :contractor)
    end
  end

  describe "#resend?" do
    it "allows the contract's own signee/organizer party to resend to another non-HCB party" do
      expect(described_class.new(organizer, contract.party(:contractor)).resend?).to eq(true)
    end

    it "denies an unrelated user" do
      expect(described_class.new(other_user, contract.party(:contractor)).resend?).to eq(false)
    end

    it "denies a signed-out user" do
      expect(described_class.new(nil, contract.party(:contractor)).resend?).to eq(false)
    end

    it "always allows an admin" do
      expect(described_class.new(admin, contract.party(:contractor)).resend?).to eq(true)
    end

    it "keeps the HCB party admin-only, even for the contract's own organizer" do
      expect(described_class.new(organizer, contract.party(:hcb)).resend?).to eq(false)
      expect(described_class.new(admin, contract.party(:hcb)).resend?).to eq(true)
    end
  end
end
