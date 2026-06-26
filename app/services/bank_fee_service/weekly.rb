# frozen_string_literal: true

module BankFeeService
  class Weekly
    def run
      bank_fees = []

      Cartel.pending_fees_v2.find_each(batch_size: 100) do |event|
        bank_fees << BankFeeService::Create.new(event_id: event.id).run
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
