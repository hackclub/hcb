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

    trait :forbidden_network_id do
      merchant_data do
        {
          category: "employment_temp_agencies",
          category_code: "7361",
          network_id: "8203300025",
          name: "HEPTA PAY LTD"
        }
      end
    end

    # A merchant whose category is forbidden but whose network ID is allowlisted.
    trait :allowlisted_network_id do
      merchant_data do
        {
          category: "non_fi_money_orders",
          category_code: "6051",
          network_id: "088011245800",
          name: "AlipayHK"
        }
      end
    end
  end
end
