# frozen_string_literal: true

require "rails_helper"

FactoryBot.define do
  factory :stripe_authorization do
    amount { 0 }
    approved { true }
    merchant_data do
      {
        category: "grocery_stores_supermarkets",
        network_id: "1234567890",
        name: "HCB-TEST"
      }
    end
    pending_request do
      {
        amount: 1000,
      }
    end
  end
end

RSpec.describe StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest, type: :model do
  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
  let(:service) { StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest.new(stripe_event: { data: { object: attributes_for(:stripe_authorization, card: { id: stripe_card.stripe_id }) } }) }

  it "gets authorizations correct 90% of the time" do
    expect(service.run).to be(true)
  end

end
