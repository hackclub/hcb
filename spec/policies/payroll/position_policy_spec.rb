# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::PositionPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:event) { create(:event, organizers: [user]) }
  let(:payee) { create(:payee, event:) }
  let(:position) { create(:payroll_position, payee:) }

  subject { described_class.new(user, position) }

  before do
    Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  describe "#edit? / #update?" do
    it "is allowed before the contract is fully signed" do
      expect(subject.edit?).to eq(true)
      expect(subject.update?).to eq(true)
    end

    it "is denied once the position's contract has been fully signed" do
      contract = Contract::PayrollPosition.create!(contractable: position, include_videos: false)
      contract.update_column(:aasm_state, "signed")

      expect(subject.edit?).to eq(false)
      expect(subject.update?).to eq(false)
    end

    it "ignores a voided contract when deciding whether terms are locked" do
      contract = Contract::PayrollPosition.create!(contractable: position, include_videos: false)
      contract.update_column(:aasm_state, "voided")

      expect(subject.edit?).to eq(true)
    end
  end

  describe "#contract?" do
    it "remains allowed once the contract is fully signed (view-only success state)" do
      contract = Contract::PayrollPosition.create!(contractable: position, include_videos: false)
      contract.update_column(:aasm_state, "signed")

      expect(subject.contract?).to eq(true)
    end
  end
end
