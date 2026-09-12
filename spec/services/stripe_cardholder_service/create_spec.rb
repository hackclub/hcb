# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardholderService::Create do
  let(:event) { create(:event) }
  let(:ip_address) { "127.0.0.1" }

  describe "#run" do
    it "raises when phone number is not verified", skip: "the verified phone number requirement is temporarily disabled" do
      user = create(:user, phone_number: "+18556254225", phone_number_verified: false)

      service = described_class.new(current_user: user, ip_address:, event_id: event.id)

      expect { service.run }.to raise_error(ArgumentError, /phone number must be verified/)
    end

    it "sends a verified US phone number to Stripe" do
      user = create(:user, phone_number: "+18556254225")
      user.update_column(:phone_number_verified, true)
      allow(StripeService::Issuing::Cardholder).to receive(:update)

      expect(StripeService::Issuing::Cardholder).to receive(:create)
        .with(hash_including(phone_number: "18556254225"))
        .and_return(double(id: "ich_123"))

      cardholder = described_class.new(current_user: user, ip_address:, event_id: event.id).run

      expect(cardholder.stripe_phone_number).to eq("18556254225")
    end

    it "sends a verified GB phone number to Stripe" do
      user = create(:user, phone_number: "+442079460000")
      user.update_column(:phone_number_verified, true)
      allow(StripeService::Issuing::Cardholder).to receive(:update)

      expect(StripeService::Issuing::Cardholder).to receive(:create)
        .with(hash_including(phone_number: "442079460000"))
        .and_return(double(id: "ich_123"))

      cardholder = described_class.new(current_user: user, ip_address:, event_id: event.id).run

      expect(cardholder.stripe_phone_number).to eq("442079460000")
    end

    it "does not send a non-US/GB phone number to Stripe" do
      user = create(:user, phone_number: "+919876543210")
      user.update_column(:phone_number_verified, true)
      allow(StripeService::Issuing::Cardholder).to receive(:update)

      expect(StripeService::Issuing::Cardholder).to receive(:create)
        .with(hash_including(phone_number: nil))
        .and_return(double(id: "ich_123"))

      cardholder = described_class.new(current_user: user, ip_address:, event_id: event.id).run

      expect(cardholder.stripe_phone_number).to be_nil
    end
  end
end
