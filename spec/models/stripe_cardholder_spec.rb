# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardholder, type: :model do
  it "is valid" do
    stripe_cardholder = build(:stripe_cardholder)
    expect(stripe_cardholder).to be_valid
  end

  it "syncs Stripe on update" do
    stripe_cardholder = create(:stripe_cardholder)

    expect(StripeService::Issuing::Cardholder).to(
      receive(:update)
        .with(
          stripe_cardholder.stripe_id,
          {
            phone_number: "+18556254225",
            billing: {
              address: {
                line1: stripe_cardholder.address_line1,
                city: stripe_cardholder.address_city,
                state: stripe_cardholder.address_state,
                postal_code: stripe_cardholder.address_postal_code,
                country: stripe_cardholder.address_country
              }
            }
          }
        )
    )

    stripe_cardholder.update!(stripe_phone_number: "+18556254225")
  end

  it "sends empty string to Stripe when phone number is cleared" do
    stripe_cardholder = create(:stripe_cardholder, stripe_phone_number: "+18556254225")

    expect(StripeService::Issuing::Cardholder).to(
      receive(:update)
        .with(
          stripe_cardholder.stripe_id,
          hash_including(phone_number: "")
        )
    )

    stripe_cardholder.update!(stripe_phone_number: nil)
  end

  it "does not send empty phone_number when phone was already blank" do
    stripe_cardholder = create(:stripe_cardholder, stripe_phone_number: nil)

    expect(StripeService::Issuing::Cardholder).to(
      receive(:update)
        .with(
          stripe_cardholder.stripe_id,
          hash_not_including(:phone_number)
        )
    )

    stripe_cardholder.update!(stripe_email: "updated@example.com")
  end

  it "drops a non-US/GB phone number before saving" do
    stripe_cardholder = create(:stripe_cardholder, stripe_phone_number: "919876543210")

    expect(stripe_cardholder.stripe_phone_number).to be_nil
  end

  it "clears a non-US/GB phone number on Stripe when it reaches an existing cardholder" do
    stripe_cardholder = create(:stripe_cardholder, stripe_phone_number: "18556254225")

    expect(StripeService::Issuing::Cardholder).to(
      receive(:update)
        .with(
          stripe_cardholder.stripe_id,
          hash_including(phone_number: "")
        )
    )

    stripe_cardholder.update!(stripe_phone_number: "919876543210")

    expect(stripe_cardholder.reload.stripe_phone_number).to be_nil
  end

  describe ".phone_number_supported?" do
    it "works for US numbers" do
      expect(StripeCardholder.phone_number_supported?("+18556254225")).to eq(true)
    end

    it "works for GB numbers" do
      expect(StripeCardholder.phone_number_supported?("+447700900123")).to eq(true)
    end

    it "does not work for numbers outside US/GB" do
      expect(StripeCardholder.phone_number_supported?("+919876543210")).to eq(false)
      expect(StripeCardholder.phone_number_supported?("+61412345678")).to eq(false)
    end

    it "does not work for Canadian numbers even though they share +1" do
      expect(StripeCardholder.phone_number_supported?("+12045551234")).to eq(false)
    end

    it "handles numbers stored without a plus sign" do
      expect(StripeCardholder.phone_number_supported?("18556254225")).to eq(true)
      expect(StripeCardholder.phone_number_supported?("919876543210")).to eq(false)
    end
  end
end
