# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayeePolicy, type: :policy do
  let(:manager) { create(:user) }
  let(:event) { create(:event, organizers: [manager]) }
  let(:payee) { create(:payee, event:, legal_entity: nil) }

  describe "#update_email?" do
    it "is allowed for a manager while the payee is unclaimed and unpaid" do
      expect(described_class.new(manager, payee).update_email?).to eq(true)
    end

    it "is denied once a payment has been sent" do
      create(:payment, :sent, payee:)

      expect(described_class.new(manager, payee).update_email?).to eq(false)
    end

    it "is denied once the recipient has claimed the payee with a legal entity" do
      payee.update!(legal_entity: create(:legal_entity))

      expect(described_class.new(manager, payee).update_email?).to eq(false)
    end

    it "is allowed for a managed recipient even after a payment has been sent" do
      payee.update!(legal_entity: create(:legal_entity, managing_event: event))
      create(:payment, :sent, payee:)

      expect(described_class.new(manager, payee).update_email?).to eq(true)
    end

    it "is denied for someone without manager access" do
      expect(described_class.new(create(:user), payee).update_email?).to eq(false)
    end
  end
end
