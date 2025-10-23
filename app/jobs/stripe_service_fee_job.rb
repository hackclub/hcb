# frozen_string_literal: true

class StripeServiceFeeJob < ApplicationJob
  queue_as :default
  def perform
    Stripe::BalanceTransaction.list({ created: { gte: [7.days.ago.to_i, DateTime.new(2024, 11, 13).to_i].max }, type: "stripe_fee" }).auto_paging_each do |balance_transaction|
      StripeServiceFee.find_or_create_by(stripe_balance_transaction_id: balance_transaction.id) do |stripe_service_fee|
        stripe_service_fee.amount_cents = balance_transaction.amount * -1
        stripe_service_fee.stripe_description = balance_transaction.description
      end
    end
  end

end
