# frozen_string_literal: true

module MetricJobs
  class CalculateStats < ApplicationJob
    queue_as :metrics

    def perform
      MetricJobs::CalculateSingle.perform_later(Metric::Hcb::Stats)
    end

  end
end
