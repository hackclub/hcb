# frozen_string_literal: true

class StripeServiceFeeJob < ApplicationJob
  queue_as :default
  def perform
    Stripe::BalanceTransaction.list({ created: { gte: [7.days.ago.to_i, DateTime.new(2024, 11, 13).to_i].max }, type: "stripe_fee" }).auto_paging_each do |balance_transaction|
      stripe_service_fee = StripeServiceFee.find_or_create_by(stripe_balance_transaction_id: balance_transaction.id) do |stripe_service_fee|
        stripe_service_fee.amount_cents = balance_transaction.amount * -1
        stripe_service_fee.stripe_description = balance_transaction.description
      end

      # Create the pending transaction (idempotent). Re-running this job is the
      # backstop for any that failed to get one on a previous pass.
      begin
        StripeServiceFeeService::CreateCanonicalPendingTransaction.new(stripe_service_fee_id: stripe_service_fee.id).run
      rescue => e
        Rails.error.report(e)
      end
    end
  end

end
