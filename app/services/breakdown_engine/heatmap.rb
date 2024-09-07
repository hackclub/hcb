# frozen_string_literal: true

module BreakdownEngine
  class Heatmap
    def initialize(event)
      @event = event
    end

    def run
      heatmap = {}
      transactions_count = 0

      start = 1.year.ago - (1.year.ago.to_date.wday % 7).day

      range = start.to_date...6.days.from_now.to_date

      range.each do |date|
        heatmap[date.to_s] = { negative: 0, positive: 0 }
      end

      transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run

      transactions.reverse.select { |transaction| heatmap.key?(transaction.date) }.each do |transaction|
        if transaction.amount > 0
          heatmap[transaction.date][:positive] += transaction.amount_cents
        elsif transaction.amount < 0
          heatmap[transaction.date][:negative] += transaction.amount_cents
        end
        transactions_count += 1
      end

      last_date = heatmap.keys.max.to_date

      {
        heatmap:,
        transactions_count:,
        maximum_positive_change: heatmap.values.map { |change| change[:positive] }.max || 0,
        maximum_negative_change: heatmap.values.map { |change| change[:negative] }.min || 0
      }
    end

  end
end
