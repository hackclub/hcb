# frozen_string_literal: true

class Metric
  class CalculateStatsJob < ApplicationJob
    queue_as :metrics

    def perform
      stats = Metric::Hcb::Stats.find_or_create

      stats.populate!
    end

  end

end
