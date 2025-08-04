# frozen_string_literal: true

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
