# frozen_string_literal: true

FactoryBot.define do
  factory :governance_admin_transfer_limit_boost, class: "Governance::Admin::Transfer::Limit::Boost" do
    association :limit, factory: :governance_admin_transfer_limit
    association :granted_by, factory: :user, access_level: :superadmin
    amount_cents { 1_000_000_00 } # $1,000,000
    reason { "Approving a one-off grant" }
  end
end
