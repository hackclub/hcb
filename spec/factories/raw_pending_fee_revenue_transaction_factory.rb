# frozen_string_literal: true

FactoryBot.define do
  factory :raw_pending_fee_revenue_transaction do
    transient do
      fee_revenue { create(:fee_revenue) }
    end

    fee_revenue_transaction_id { fee_revenue.id.to_s }
    amount_cents { fee_revenue.amount_cents }
    date_posted { Date.current }
  end
end
