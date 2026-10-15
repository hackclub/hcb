# frozen_string_literal: true

FactoryBot.define do
  factory :raw_stripe_transaction do
    amount_cents { Faker::Number.number(digits: 4) }
    unique_bank_identifier { "STRIPEISSUING1" }
    transient do
      sequence(:stripe_transaction_id) { |n| "ipi_#{n}" }
      stripe_card { create(:stripe_card, :with_stripe_id) }
      stripe_merchant_category { "bakeries" }
      stripe_merchant_name { Faker::Company.name }
      stripe_merchant_network_id { nil }
      stripe_merchant_category_code { nil }
      stripe_created { nil }
    end

    stripe_transaction do
      {
        "id"            => stripe_transaction_id,
        "card"          => stripe_card.stripe_id,
        "type"          => "capture",
        "amount"        => -amount_cents,
        "cardholder"    => stripe_card.stripe_cardholder.id,
        "created"       => stripe_created,
        "merchant_data" => {
          "name"          => stripe_merchant_name,
          "category"      => stripe_merchant_category,
          "category_code" => stripe_merchant_category_code,
          "network_id"    => stripe_merchant_network_id,
        }.compact,
      }.compact
    end
  end
end
