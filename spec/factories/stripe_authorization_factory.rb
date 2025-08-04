# frozen_string_literal: true

FactoryBot.define do
  factory :stripe_authorization do
    amount { 0 }
    approved { true }
    merchant_data do
      {
        category: "grocery_stores_supermarkets",
        category_code: "5411",
        network_id: "1234567890",
        name: "HCB-TEST"
      }
    end
    pending_request do
      {
        amount: 1000,
      }
    end

    trait :cash_withdrawal do
      merchant_data do
        {
          category: "automated_cash_disburse",
          category_code: "6011",
          network_id: "1234567890",
          name: "HCB-ATM-TEST"
        }
      end
    end
  end
end
