# frozen_string_literal: true

module CanonicalTransactionService
  module Stats
    class During
      def initialize(start_time: Date.parse("2015-01-01"), end_time: Date.today)
        @start_time = start_time.to_datetime
        @end_time = end_time.to_datetime
      end

      def run
        {
          transactions_volume: tx.sum("abs(amount_cents)"),
          expenses: tx.expense.sum(:amount_cents),
          raised: tx.revenue.sum(:amount_cents),
          revenue: tx.includes(:fee).sum("fees.amount_cents_as_decimal").to_i,
          size: {
            total: tx.size,
            raised: tx.revenue.size,
            expenses: tx.expense.size,
          },
          start_time: @start_time,
          end_time: @end_time,
        }
      end

      private

      def tx
        CanonicalTransaction.included_in_stats
                            .where(date: @start_time..@end_time)
      end

    end
  end
end
