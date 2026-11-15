# frozen_string_literal: true

FactoryBot.define do
  factory :legal_entity_payout_method, class: "LegalEntity::PayoutMethod" do
    association :legal_entity
    association :details, factory: :ach_transfer_payout_method_details
    default { false }
  end

  factory :ach_transfer_payout_method_details, class: "LegalEntity::PayoutMethod::AchTransfer" do
    account_number { "123456789" }
    routing_number { "021000021" }
  end

  factory :check_payout_method_details, class: "LegalEntity::PayoutMethod::Check" do
    address_line1       { "123 Main St" }
    address_city        { "San Francisco" }
    address_state       { "CA" }
    address_postal_code { "94102" }
    address_country     { "US" }
  end

  factory :wire_payout_method_details, class: "LegalEntity::PayoutMethod::Wire" do
    account_number    { "GB29NWBK60161331926819" }
    bic_code          { "NWBKGB2L" }
    recipient_country { 1 }
  end

  factory :wise_transfer_payout_method_details, class: "LegalEntity::PayoutMethod::WiseTransfer" do
    address_line1       { "123 Main St" }
    address_city        { "London" }
    address_state       { "England" }
    address_postal_code { "SW1A 1AA" }
    recipient_country   { 1 }
    currency            { "GBP" }
  end
end
