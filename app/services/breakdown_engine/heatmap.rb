# frozen_string_literal: true

module BreakdownEngine
  class Heatmap
    def initialize(event)
      @event = event
    end

    def run
      heatmap = {}

      start = 1.year.ago - (1.year.ago.to_date.wday % 7).day

      range = start.to_date...6.days.from_now.to_date

      range.each do |date|
        heatmap[date.to_s] = 0
      end

      settled_transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
      pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(event_id: @event.id).run

      all_transactions = settled_transactions.concat(pending_transactions)
      transactions_in_range = all_transactions.select { |transaction| heatmap.key?(transaction.date.to_s) }

      transactions_in_range.each do |transaction|
        heatmap[transaction.date.to_s] += transaction.amount_cents
      end

      {
        heatmap:,
        transactions_count: transactions_in_range.size,
        maximum_positive_change: heatmap.values.max || 0,
        maximum_negative_change: heatmap.values.min || 0
      }
    end

  end
end
