# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::TerminationRequestPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:request) { build(:event_termination_request, event:) }

  def policy_for(user)
    described_class.new(user, request)
  end

  describe "#create?" do
    it "permits a contract signee" do
      signee = create(:user)
      create(:organizer_position, user: signee, event:, role: :manager, is_signee: true)

      expect(policy_for(signee).create?).to eq(true)
    end

    it "denies a manager who has not signed the contract" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)

      expect(policy_for(manager).create?).to eq(false)
    end

    it "denies a signee of a different organization" do
      signee = create(:user)
      create(:organizer_position, user: signee, event: create(:event), is_signee: true)

      expect(policy_for(signee).create?).to eq(false)
    end

    it "denies admins who are not signees" do
      expect(policy_for(create(:user, :make_admin)).create?).to eq(false)
    end

    it "denies signed-out visitors" do
      expect(policy_for(nil).create?).to eq(false)
    end
  end

  describe "#withdraw?" do
    let(:signee) { create(:user) }

    before { create(:organizer_position, user: signee, event:, is_signee: true) }

    it "permits any signee of the organization while the request is pending" do
      request = create(:event_termination_request, event:, requested_by: create(:user))

      expect(described_class.new(signee, request).withdraw?).to eq(true)
    end

    it "denies once the request is no longer pending" do
      request = create(:event_termination_request, event:, requested_by: signee)
      request.withdraw!

      expect(described_class.new(signee, request).withdraw?).to eq(false)
    end

    it "denies a non-signee member" do
      member = create(:user)
      create(:organizer_position, user: member, event:)
      request = create(:event_termination_request, event:, requested_by: signee)

      expect(described_class.new(member, request).withdraw?).to eq(false)
    end
  end

  describe "admin actions" do
    it "limits index and show to auditors, and close and reopen to admins" do
      auditor = create(:user, access_level: :auditor)
      admin = create(:user, :make_admin)
      organizer = create(:user)

      expect(policy_for(auditor).index?).to eq(true)
      expect(policy_for(auditor).show?).to eq(true)
      expect(policy_for(auditor).close?).to eq(false)
      expect(policy_for(admin).close?).to eq(true)
      expect(policy_for(admin).reopen?).to eq(true)
      expect(policy_for(organizer).index?).to eq(false)
    end
  end
end
