# frozen_string_literal: true

class Metric
  class CalculateSingleJob < ApplicationJob
    queue_as :metrics

    def perform(metric_class, record = nil)
      metric_class.from(record, repopulate: true)
    end

  end

end

module MetricJobs
  CalculateSingle = Metric::CalculateSingleJob
end
