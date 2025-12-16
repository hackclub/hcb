# frozen_string_literal: true

class Metric
  class CreateAppWideJob < ApplicationJob
    queue_as :low
    # Don't retry job, reattempt at next cron scheduled run
    discard_on(StandardError) do |job, error|
      Rails.error.report error
    end

    def perform
      metric_classes.each do |metric_class|
        metric_class.queue_for_later_from(nil)
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
