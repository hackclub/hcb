# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoicePolicy, type: :policy do
  let(:organizer) { create(:user) }
  let(:event) { create(:event, organizers: [organizer]) }
  let(:legal_entity) { create(:legal_entity) }
  let(:payee) { create(:payee, event:, legal_entity:) }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
  let(:invoice) { position.invoices.build }

  before do
    Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  describe "#on_behalf?" do
    it "is allowed for an organizer who can review the position" do
      expect(described_class.new(organizer, invoice).on_behalf?).to eq(true)
    end

    it "is denied for the contractor themselves, even when they can review the position" do
      create(:legal_entity_user, legal_entity:, user: organizer)

      policy = described_class.new(organizer, invoice)
      expect(policy.on_behalf?).to eq(false)
      expect(policy.create?).to eq(true)
    end

    it "is denied for a user with no permissions on the event" do
      expect(described_class.new(create(:user), invoice).on_behalf?).to eq(false)
    end

    it "is denied before the position has finished onboarding" do
      position.update_column(:aasm_state, "onboarding")

      policy = described_class.new(organizer, invoice)
      expect(policy.on_behalf?).to eq(false)
      expect(policy.new?).to eq(false)
      expect(policy.create?).to eq(false)
    end
  end
end
