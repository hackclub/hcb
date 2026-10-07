# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntityPolicy, type: :policy do
  let(:legal_entity) { create(:legal_entity) }
  let(:owner) { create(:user).tap { |user| legal_entity.users << user } }
  let(:stranger) { create(:user) }
  let(:auditor) { create(:user, access_level: :auditor) }
  let(:admin) { create(:user, access_level: :admin) }

  describe "#show_masked_tin?" do
    it "lets the taxpayer see their own masked TIN" do
      expect(described_class.new(owner, legal_entity).show_masked_tin?).to be true
    end

    it "does not let an admin see a payee's masked TIN" do
      expect(described_class.new(admin, legal_entity).show_masked_tin?).to be false
    end

    it "does not let an auditor see a payee's masked TIN" do
      expect(described_class.new(auditor, legal_entity).show_masked_tin?).to be false
    end

    it "does not let an unrelated user see a payee's masked TIN" do
      expect(described_class.new(stranger, legal_entity).show_masked_tin?).to be false
    end
  end

  describe "#switch?" do
    it "lets the owner move their own entity's pending payments" do
      expect(described_class.new(owner, legal_entity).switch?).to be true
    end

    it "does not let an unrelated user move someone else's pending payments" do
      expect(described_class.new(stranger, legal_entity).switch?).to be false
    end

    it "does not let a non-member admin move someone else's pending payments" do
      expect(described_class.new(admin, legal_entity).switch?).to be false
    end
  end

  describe "the actions the controllers authorize" do
    # LegalEntitiesController calls `authorize` with each of these. A missing one
    # raises NoMethodError at request time rather than denying access.
    it "defines every policy method the controllers ask for" do
      policy = described_class.new(owner, legal_entity)

      expect(policy).to respond_to(:show?, :replace?, :switch?, :show_masked_tin?)
    end
  end
end
