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

      FeeRevenue.create!(
        bank_fees:,
        amount_cents: bank_fees.sum { |fee| -fee.amount_cents },
        start: Date.today.last_week, # The previous Monday
        end: Date.yesterday
      )

      true
    end

  end
end
