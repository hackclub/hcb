# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationJwtService do
  include DonationSupport

  let(:event) { create(:event) }
  let(:donation) do
    create(:donation,
           event:,
           amount: 10000, # $100.00
           name: "John Doe",
           email: "john@example.com")
  end

  before do
    stub_donation_payment_intent_creation
  end

  describe ".generate_token" do
    it "generates a valid JWT token" do
      token = described_class.generate_token(donation)

      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end

    it "includes donation details in the payload" do
      token = described_class.generate_token(donation)
      payload = described_class.verify_token(token)

      expect(payload).to be_present
      expect(payload["id"]).to eq(donation.public_id)
      expect(payload["name"]).to eq("John Doe")
      expect(payload["amount"]).to eq(10000)
    end

    it "respects anonymous donations" do
      donation.update(anonymous: true)
      token = described_class.generate_token(donation)
      payload = described_class.verify_token(token)

      expect(payload["name"]).to eq("Anonymous")
    end

    it "includes expiration time" do
      token = described_class.generate_token(donation)
      payload = described_class.verify_token(token)

      expect(payload["exp"]).to be > Time.now.to_i
      expect(payload["exp"]).to be <= (Time.now + 1.hour).to_i
      expect(payload["iat"]).to be_present
    end
  end

  describe ".verify_token" do
    it "verifies a valid token" do
      token = described_class.generate_token(donation)
      payload = described_class.verify_token(token)

      expect(payload).to be_present
      expect(payload["id"]).to eq(donation.public_id)
    end

    it "rejects a tampered token" do
      token = described_class.generate_token(donation)
      tampered_token = token.chars.tap { |c| c[-5] = "x" }.join

      payload = described_class.verify_token(tampered_token)

      expect(payload).to be_nil
    end

    it "rejects an invalid token format" do
      invalid_token = "invalid.token"

      payload = described_class.verify_token(invalid_token)

      expect(payload).to be_nil
    end

    it "rejects an expired token" do
      # Travel to the future to expire the token
      token = described_class.generate_token(donation)

      travel_to(Time.now + 2.hours) do
        payload = described_class.verify_token(token)
        expect(payload).to be_nil
      end
    end
  end
end
