# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntityUser, type: :model do
  describe "validations" do
    describe "#person_entities_have_one_user" do
      context "when the legal entity is a person" do
        let(:user) { create(:user) }
        # The user's auto-created person entity is the one we test against,
        # so we don't need to create a separate one.
        let(:person_entity) { user.legal_entities.find_by(entity_type: :person) }

        it "is valid on the existing auto-created person entity user record" do
          legal_entity_user = LegalEntityUser.find_by(user:, legal_entity: person_entity)
          expect(legal_entity_user).to be_valid
        end

        it "is invalid when a second user is linked to the same person entity" do
          second_user = create(:user)
          duplicate = build(:legal_entity_user, legal_entity: person_entity, user: second_user)

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:base]).to include("Legal entities with type person can only have one user")
        end
      end

      context "when the legal entity is not a person" do
        let(:non_person_entity) { create(:legal_entity, :business) }

        it "allows multiple users on the same business entity" do
          create(:legal_entity_user, legal_entity: non_person_entity)
          second = build(:legal_entity_user, legal_entity: non_person_entity)

          expect(second).to be_valid
        end
      end
    end

    describe "#user_only_has_one_person_entity" do
      context "when the legal entity is a person" do
        let(:user) { create(:user) }
        let(:existing_person_entity) { user.legal_entities.find_by(entity_type: :person) }

        it "is valid on the auto-created person entity user record" do
          legal_entity_user = LegalEntityUser.find_by(user:, legal_entity: existing_person_entity)
          expect(legal_entity_user).to be_valid
        end

        it "is invalid when trying to link the user to a second person entity" do
          second_person_entity = create(:legal_entity, :person)
          duplicate = build(:legal_entity_user, legal_entity: second_person_entity, user:)

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:base]).to include("Users can only have one non-archived person legal entity")
        end
      end

      context "when the legal entity is not a person" do
        let(:user) { create(:user) }

        it "allows the user to belong to multiple business entities" do
          create(:legal_entity_user, legal_entity: create(:legal_entity, :business), user:)
          second = build(:legal_entity_user, legal_entity: create(:legal_entity, :business), user:)

          expect(second).to be_valid
        end

        it "allows a user with an auto-created person entity to also belong to a business entity" do
          business_leu = build(:legal_entity_user, legal_entity: create(:legal_entity, :business), user:)
          expect(business_leu).to be_valid
        end
      end
    end
  end
end
