# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCard, type: :model do
  context "without stripe id" do
    let(:stripe_card) { create(:stripe_card) }

    it "is valid" do
      expect(stripe_card).to be_valid
    end
  end

  context "with stripe id" do
    let(:stripe_card) { create(:stripe_card, :with_stripe_id) }

    it "is valid" do
      expect(stripe_card).to be_valid
    end
  end

  describe "search" do
    let(:user) { create(:user, full_name: "Orpheus Dinosaur", preferred_name: "Orph") }
    let!(:stripe_card) { create(:stripe_card, :with_stripe_id, name: "Hardware budget", stripe_cardholder: create(:stripe_cardholder, user:)) }
    let!(:other_card) { create(:stripe_card, :with_stripe_id, name: "Snacks", last4: "1234") }

    it "matches card name, last four, and cardholder for organizers" do
      expect(StripeCard.search("hardware")).to contain_exactly(stripe_card)
      expect(StripeCard.search("9876")).to contain_exactly(stripe_card)
      expect(StripeCard.search("dinosaur")).to contain_exactly(stripe_card)
      expect(StripeCard.search("orph")).to contain_exactly(stripe_card)
    end

    it "only matches card name and preferred name for the public" do
      expect(StripeCard.public_search("hardware")).to contain_exactly(stripe_card)
      expect(StripeCard.public_search("orph")).to contain_exactly(stripe_card)
      expect(StripeCard.public_search("dinosaur")).to be_empty
      expect(StripeCard.public_search("9876")).to be_empty
    end
  end
end
