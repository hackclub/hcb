# frozen_string_literal: true

module AssertsRequirements
  extend ActiveSupport::Concern

  included do
    class FailedAssertionError < StandardError; end

    class FailedJobError < StandardError; end

    def report_anomaly(message)
      @anomalies << message
      Rails.error.report(FailedAssertionError.new(message))
    end

    def perform
      @anomalies = []

      run

      if @anomalies.any?
        Rails.error.report(FailedJobError.new("#{self.class.name} failed with #{@anomalies.count} anomalies"))
      end

      @anomalies
    end
  end
end
