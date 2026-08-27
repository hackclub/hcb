# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    association :sponsor
    association :creator, factory: :user
    item_description { Faker::Commerce.product_name }
    item_amount { Faker::Number.number(digits: 4) }
    payout_creation_balance_net { Faker::Number.number(digits: 4) }
    payout_creation_balance_stripe_fee { Faker::Number.number(digits: 4) }
    due_date { Faker::Date.forward(days: 14) }

    trait :with_line_items do
      transient do
        line_items_count { 2 }
      end

      after(:create) do |invoice, evaluator|
        create_list(:invoice_line_item, evaluator.line_items_count, invoice:)
      end
    end
  end

  factory :invoice_line_item, class: "Invoice::LineItem" do
    association :invoice
    description { Faker::Commerce.product_name }
    amount { Faker::Number.between(from: 100, to: 100_000) }
  end
end
