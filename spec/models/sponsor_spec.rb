# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sponsor, type: :model do
  it "is valid" do
    sponsor = build(:sponsor)
    expect(sponsor).to be_valid
  end

  it "creates a stripe customer" do
    sponsor = build(:sponsor)

    expect(StripeService::Customer).to(
      receive(:create)
        .with(
          {
            description: sponsor.name,
            email: sponsor.contact_email,
            shipping: {
              name: sponsor.name,
              address: {
                line1: sponsor.address_line1,
                line2: sponsor.address_line2,
                city: sponsor.address_city,
                state: sponsor.address_state,
                postal_code: sponsor.address_postal_code,
                country: sponsor.address_country
              }
            }
          }
        )
        .and_return(Stripe::Customer.construct_from(id: "cu_1234"))
    )

    sponsor.save!

    expect(sponsor.stripe_customer_id).to eq("cu_1234")
  end
end
