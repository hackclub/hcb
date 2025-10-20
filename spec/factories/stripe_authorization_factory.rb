# frozen_string_literal: true

FactoryBot.define do
  factory(:stripe_authorization, class: "Stripe::Issuing::Authorization") do
    skip_create
    initialize_with { Stripe::Issuing::Authorization.construct_from(attributes) }

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
        amount: pending_amount,
      }
    end

    transient do
      pending_amount { 10_00 }
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

    trait :gambling do
      merchant_data do
        {
          category: "betting_casino_gambling",
          category_code: "7995",
          network_id: "1234567890",
          name: "CASINO"
        }
      end
    end
  end
end
