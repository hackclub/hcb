# frozen_string_literal: true

module MetricJobs
  class CalculateSingle < ApplicationJob
    queue_as :metrics

    def perform(metric_class, record = nil)
      metric_class.from(record, repopulate: true)
    end

  end
end
