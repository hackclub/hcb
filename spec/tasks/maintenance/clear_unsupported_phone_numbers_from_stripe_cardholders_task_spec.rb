# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::ClearUnsupportedPhoneNumbersFromStripeCardholdersTask do
  describe "#collection" do
    it "only includes cardholders that have a phone number and a stripe id" do
      with_number = create(:stripe_cardholder, stripe_phone_number: "18556254225")
      create(:stripe_cardholder, stripe_phone_number: nil)
      create(:stripe_cardholder, stripe_phone_number: "")
      create(:stripe_cardholder, stripe_phone_number: "18556254225", stripe_id: nil)
      create(:stripe_cardholder, stripe_phone_number: "18556254225", stripe_id: "")

      expect(described_class.new.collection).to contain_exactly(with_number)
    end
  end

  # rows with international numbers predate the before_validation on the model,
  # so they have to be written around it here
  describe "#process" do
    it "clears a phone number outside +1/+44" do
      cardholder = create(:stripe_cardholder)
      cardholder.update_column(:stripe_phone_number, "919876543210")

      expect(StripeService::Issuing::Cardholder).to receive(:update).with(cardholder.stripe_id, hash_including(phone_number: ""))

      described_class.new.process(cardholder)

      expect(cardholder.reload.stripe_phone_number).to be_nil
    end

    it "leaves US phone numbers alone" do
      cardholder = create(:stripe_cardholder, stripe_phone_number: "18556254225")

      expect(StripeService::Issuing::Cardholder).not_to receive(:update)

      described_class.new.process(cardholder)

      expect(cardholder.reload.stripe_phone_number).to eq("18556254225")
    end

    it "leaves GB phone numbers alone" do
      cardholder = create(:stripe_cardholder, stripe_phone_number: "447700900123")

      expect(StripeService::Issuing::Cardholder).not_to receive(:update)

      described_class.new.process(cardholder)

      expect(cardholder.reload.stripe_phone_number).to eq("447700900123")
    end

    it "reports and moves on when stripe rejects the update" do
      cardholder = create(:stripe_cardholder)
      cardholder.update_column(:stripe_phone_number, "919876543210")

      allow(StripeService::Issuing::Cardholder).to receive(:update).and_raise(Stripe::InvalidRequestError.new("no such cardholder", "id"))
      # the model only re-raises stripe errors in production
      allow(Rails.env).to receive(:production?).and_return(true)
      expect(Rails.error).to receive(:report)

      expect { described_class.new.process(cardholder) }.not_to raise_error
      expect(cardholder.reload.stripe_phone_number).to eq("919876543210")
    end

    it "reports and moves on when stripe complains about the billing address" do
      cardholder = create(:stripe_cardholder)
      cardholder.update_column(:stripe_phone_number, "919876543210")

      allow(StripeService::Issuing::Cardholder).to receive(:update).and_raise(Stripe::InvalidRequestError.new("Invalid address", "billing"))
      expect(Rails.error).to receive(:report).with(an_instance_of(ActiveRecord::RecordInvalid), context: { stripe_cardholder_id: cardholder.id })

      expect { described_class.new.process(cardholder) }.not_to raise_error
      expect(cardholder.reload.stripe_phone_number).to eq("919876543210")
    end
  end
end
