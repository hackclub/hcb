# frozen_string_literal: true

module BankFeeService
  class Weekly
    def run
      bank_fees = []

      BankFee.pending.find_each(batch_size: 100) do |bank_fee|
        bank_fees << bank_fee
        bank_fee.mark_confirmed!
        bank_fee.event.update_column(:last_fee_processed_at, Time.now)
      end

      return if bank_fees.empty?

      fee_revenue = FeeRevenue.create!(
        bank_fees:,
        amount_cents: bank_fees.sum { |fee| -fee.amount_cents },
        start: Date.today.last_week, # The previous Monday
        end: Date.yesterday
      )

      # Create the pending transaction outside the FeeRevenue.create! above so a
      # failure here doesn't roll back the fee revenue itself; BankFeeService::Nightly
      # retries any that slip through.
      FeeRevenueService::CreateCanonicalPendingTransaction.new(fee_revenue_id: fee_revenue.id).run

      true
    end

  end
end
