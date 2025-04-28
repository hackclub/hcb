# frozen_string_literal: true

class Metric
  class CalculateStatsJob < ApplicationJob
    queue_as :metrics

    def perform
      Metric::CalculateSingleJob.perform_later(Metric::Hcb::Stats)
    end

  end

end

module MetricJobs
  CalculateStats = Metric::CalculateStatsJob
end
