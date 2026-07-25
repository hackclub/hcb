# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payee, type: :model do
  describe "validations" do
    describe "uniqueness of legal_entity_id scoped to event_id" do
      let(:event) { create(:event) }
      let(:legal_entity) { create(:legal_entity) }

      it "is valid when the legal entity is not yet linked to the event" do
        payee = build(:payee, event:, legal_entity:)
        expect(payee).to be_valid
      end

      it "is invalid when the same legal entity is linked to the same event twice" do
        create(:payee, event:, legal_entity:)
        duplicate = build(:payee, event:, legal_entity:)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:legal_entity_id]).to include("has already been taken")
      end

      it "allows the same legal entity to be linked to different events" do
        other_event = create(:event)
        create(:payee, event:, legal_entity:)
        payee = build(:payee, event: other_event, legal_entity:)

        expect(payee).to be_valid
      end

      it "allows different legal entities to be linked to the same event" do
        other_legal_entity = create(:legal_entity)
        create(:payee, event:, legal_entity:)
        payee = build(:payee, event:, legal_entity: other_legal_entity)

        expect(payee).to be_valid
      end
    end
  end

  describe "seeding legacy payout methods when the recipient links an entity" do
    let(:event) do
      event = create(:event)
      create(:canonical_pending_transaction, amount_cents: 1_000_000, event:, fronted: true)
      event
    end

    before do
      create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                            account_number: "123456789", routing_number: "110000000")
    end

    it "seeds the reconstructed method onto the newly linked entity" do
      payee = create(:payee, event:, legal_entity: nil, email: "orpheus@hackclub.com")
      le = create(:legal_entity)

      expect { payee.update!(legal_entity: le) }.to change { le.payout_methods.count }.by(1)
      expect(le.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
    end

    it "does not seed when no legacy transfer matches the recipient's email" do
      payee = create(:payee, event:, legal_entity: nil, email: "someone-else@hackclub.com")
      le = create(:legal_entity)

      expect { payee.update!(legal_entity: le) }.not_to(change { le.payout_methods.count })
    end

    it "does not clobber payout methods the recipient already set up" do
      payee = create(:payee, event:, legal_entity: nil, email: "orpheus@hackclub.com")
      le = create(:legal_entity)
      le.payout_methods.create!(default: true, details: LegalEntity::PayoutMethod::Check.new(
        address_line1: "1 Infinite Loop", address_city: "Cupertino", address_state: "CA",
        address_postal_code: "95014", address_country: "US"
      ))

      expect { payee.update!(legal_entity: le) }.not_to(change { le.payout_methods.count })
    end
  end
end
