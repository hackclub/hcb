# frozen_string_literal: true

class Metric
  class PopulateJob < ApplicationJob
    queue_as :metrics

    def perform(metric_instance)
      metric_instance.populate!
    end

  end

end
