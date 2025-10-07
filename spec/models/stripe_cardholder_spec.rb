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
end
