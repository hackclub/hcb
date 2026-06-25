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
end
