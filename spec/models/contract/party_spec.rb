# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contract::Party, type: :model do
  describe "role scoping to contract type" do
    # Unsaved contracts are enough here: the validation only reads
    # #permitted_roles and #model_name, so we avoid the contractable +
    # after_create HCB-party machinery.
    let(:fiscal_sponsorship) { Contract::FiscalSponsorship.new }
    let(:payroll_position) { Contract::PayrollPosition.new }

    def role_errors(contract:, role:)
      party = described_class.new(contract:, role:)
      party.valid?
      party.errors[:role]
    end

    context "fiscal sponsorship contract" do
      it "permits its own roles" do
        %w[hcb signee cosigner].each do |role|
          expect(role_errors(contract: fiscal_sponsorship, role:)).to be_empty
        end
      end

      it "rejects payroll roles" do
        %w[organizer contractor].each do |role|
          expect(role_errors(contract: fiscal_sponsorship, role:))
            .to include(a_string_including("not a valid party for a fiscal sponsorship"))
        end
      end
    end

    context "payroll position contract" do
      it "permits its own roles" do
        %w[hcb organizer contractor].each do |role|
          expect(role_errors(contract: payroll_position, role:)).to be_empty
        end
      end

      it "rejects fiscal sponsorship roles" do
        %w[signee cosigner].each do |role|
          expect(role_errors(contract: payroll_position, role:))
            .to include(a_string_including("not a valid party for a payroll position"))
        end
      end
    end
  end

  describe "#permitted_roles is a superset of #required_roles" do
    [Contract::FiscalSponsorship, Contract::PayrollPosition].each do |klass|
      it "holds for #{klass}" do
        contract = klass.new
        expect(contract.required_roles).to all(be_in(contract.permitted_roles))
      end
    end
  end

  describe ".for" do
    let(:event) { create(:event) }
    let(:signee) { create(:user) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    # Parties can only be added while a contract is pending, so build the
    # contract, add the signee, and only then move it to sent.
    def send_contract_for(user, on: event)
      invite = create(:organizer_position_invite, event: on, user:)
      contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false)
      party = contract.parties.create!(user:, role: :signee)
      contract.update_column(:aasm_state, "sent")

      party
    end

    it "returns the user's own party" do
      party = send_contract_for(signee)

      expect(described_class.for(event:, user: signee)).to eq party
    end

    it "returns nothing for a user who is not a party" do
      send_contract_for(signee)

      expect(described_class.for(event:, user: create(:user))).to be_nil
    end

    it "does not return a party on another organization's contract" do
      send_contract_for(signee)
      other_event = create(:event)
      send_contract_for(create(:user), on: other_event)

      expect(described_class.for(event: other_event, user: signee)).to be_nil
    end

    it "returns each signee their own party when several contracts are open" do
      first_party = send_contract_for(signee)
      other_signee = create(:user)
      second_party = send_contract_for(other_signee)

      expect(described_class.for(event:, user: signee)).to eq first_party
      expect(described_class.for(event:, user: other_signee)).to eq second_party
    end

    it "returns HCB's party on this organization's contract to an admin who is not a party" do
      party = send_contract_for(signee)
      send_contract_for(create(:user), on: create(:event))

      expect(described_class.for(event:, user: create(:user, :make_admin)))
        .to eq party.contract.party(:hcb)
    end

    it "returns an admin their own party rather than HCB's" do
      party = send_contract_for(signee)
      signee.update!(access_level: :admin)

      expect(described_class.for(event:, user: signee)).to eq party
    end

    it "does not return HCB's party to an auditor" do
      send_contract_for(signee)

      expect(described_class.for(event:, user: create(:user, :make_auditor))).to be_nil
    end

    # Whatever this offers, Contract::PartyPolicy#show? has to allow, or the
    # banner links somewhere the viewer bounces off. The reverse is deliberately
    # untrue: the policy also allows anyone to open a party that has no user, so
    # this must stay the narrower of the two.
    it "only returns parties the policy would let that user open" do
      send_contract_for(signee)

      [signee, create(:user, :make_admin)].each do |user|
        party = described_class.for(event:, user:)

        expect(party).to be_present
        expect(Contract::PartyPolicy.new(user, party).show?).to be true
      end
    end

    # The banner that calls this renders for signed out visitors too, and
    # Contract::PartyPolicy#show? lets anyone open a party that has no user, so
    # this guard is the only thing keeping a cosigner's signing link private.
    it "returns nothing to a signed out visitor, even when a party has no HCB account" do
      invite = create(:organizer_position_invite, event:, user: signee)
      contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false)
      contract.parties.create!(user: signee, role: :signee)
      contract.parties.create!(role: :cosigner, external_email: "parent@example.com")
      contract.update_column(:aasm_state, "sent")

      expect(described_class.for(event:, user: nil)).to be_nil
    end

    it "ignores contracts that have not been sent" do
      invite = create(:organizer_position_invite, event:, user: signee)
      contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false)
      contract.parties.create!(user: signee, role: :signee)

      expect(described_class.for(event:, user: signee)).to be_nil
    end
  end
end
