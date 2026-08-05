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

    describe "email" do
      it "normalizes case and surrounding whitespace" do
        payee = create(:payee, email: "  Contractor@Example.COM ")
        expect(payee.email).to eq("contractor@example.com")
      end

      it "rejects a malformed email when it changes" do
        payee = create(:payee)
        payee.email = "not-an-email"

        expect(payee).not_to be_valid
        expect(payee.errors[:email]).to be_present
      end

      it "still allows other attributes to be updated on a row with a malformed email" do
        payee = create(:payee)
        payee.update_column(:email, "legacy-garbage")

        expect(payee.update(display_name: "Renamed")).to eq(true)
      end
    end
  end

  describe "#email_editable?" do
    let(:event) { create(:event) }

    it "is true for an unclaimed recipient with no payments" do
      expect(create(:payee, event:, legal_entity: nil).email_editable?).to eq(true)
    end

    it "is true while payments are still waiting on the recipient to claim it" do
      payee = create(:payee, event:, legal_entity: nil)
      create(:payment, :pending_legal_entity, payee:)
      create(:payment, :under_review, payee:)

      expect(payee.email_editable?).to eq(true)
    end

    it "is false once the recipient has claimed it by linking a legal entity" do
      payee = create(:payee, event:, legal_entity: create(:legal_entity))

      expect(payee.email_editable?).to eq(false)
    end

    it "is false once a payment has been sent" do
      payee = create(:payee, event:, legal_entity: nil)
      create(:payment, :sent, payee:)

      expect(payee.email_editable?).to eq(false)
    end

    it "is false once a payment has succeeded" do
      payee = create(:payee, event:, legal_entity: nil)
      create(:payment, :successful, payee:)

      expect(payee.email_editable?).to eq(false)
    end

    it "is true for a managed recipient even after payments have been sent" do
      payee = create(:payee, event:, legal_entity: create(:legal_entity, managing_event: event))
      create(:payment, :successful, payee:)

      expect(payee).to be_managed
      expect(payee.email_editable?).to eq(true)
    end
  end
end
