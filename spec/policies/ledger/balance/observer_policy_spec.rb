# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Balance::ObserverPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:observer) { build(:ledger_balance_observer, ledger: event.ledger, user:) }

  describe "#create?" do
    subject { described_class.new(user, observer).create? }

    it "is denied without access to the ledger" do
      is_expected.to eq(false)
    end

    it "is allowed for a reader of the ledger's organization" do
      create(:organizer_position, user:, event:, role: :reader)

      is_expected.to eq(true)
    end

    it "is denied for an observer belonging to someone else, even for a manager" do
      create(:organizer_position, user:, event:, role: :manager)
      observer.user = create(:user)

      is_expected.to eq(false)
    end
  end

  describe "#destroy?" do
    it "is allowed only for the observer's own user" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)

      expect(described_class.new(user, observer).destroy?).to eq(true)
      expect(described_class.new(manager, observer).destroy?).to eq(false)
      expect(described_class.new(nil, build(:ledger_balance_observer, user: nil)).destroy?).to eq(false)
    end
  end
end
