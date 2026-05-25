# frozen_string_literal: true

FactoryBot.define do
  factory :governance_admin_transfer_limit, class: "Governance::Admin::Transfer::Limit" do
    association :user, factory: [:user, :make_admin]
    amount_cents { 1_000_000_00 } # $1,000,000 default limit
  end
end
