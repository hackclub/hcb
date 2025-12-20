# frozen_string_literal: true

class Metric
  class CalculateStatsJob < ApplicationJob
    queue_as :metrics

    def perform
      stats = Metric::Hcb::Stats.first_or_initialize

      stats.populate!
    end

  end

end
