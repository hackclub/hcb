# frozen_string_literal: true

module BalanceGraph
  extend ActiveSupport::Concern

  private

  def balance_graph_for(event)
    max = [365, (Date.today - event.created_at.to_date).to_i + 5].min

    data = Rails.cache.fetch("balance_by_date_#{event.id}", expires_in: 5.minutes) do
      ::TransactionGroupingEngine::Transaction::All.new(event_id: event.id).running_balance_by_date
    end

    data[Date.today] = event.balance_v2_cents

    trend = begin
      oldest = data[max.days.ago.to_date] || data[data.keys.first]
      oldest > event.balance_v2_cents ? "down" : "up"
    rescue
      "up"
    end

    { data:, trend: }
  end
end
