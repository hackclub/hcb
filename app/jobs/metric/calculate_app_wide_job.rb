# frozen_string_literal: true

class Metric
  class CalculateAppWideJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    discard_on(StandardError) do |job, error|
      Airbrake.notify(error)
    end

    def perform
      metric_classes.each do |metric_class|
        Metric::CalculateSingleJob.perform_later(metric_class)
      end
    end

    private

    def metric_classes
      Metric.descendants.select do |c|
        c.included_modules.include?(Metric::AppWide)
      end
    end

  end

end

module MetricJobs
  CalculateAppWide = Metric::CalculateAppWideJob
end
