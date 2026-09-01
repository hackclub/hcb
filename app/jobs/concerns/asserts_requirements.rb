# frozen_string_literal: true

module AssertsRequirements
  class FailedAssertionError < StandardError; end
  class FailedJobError < StandardError; end

  extend ActiveSupport::Concern

  included do
    def report_anomaly(message)
      @anomalies << message
      Rails.error.report(AssertsRequirements::FailedAssertionError.new(message))
    end

    def perform
      @anomalies = []

      run

      if @anomalies.any?
        Rails.error.report(AssertsRequirements::FailedJobError.new("#{self.class.name} failed with #{@anomalies.count} anomalies (#{job_id})"))
        AdminMailer.failed_assertion_job(job: self.class.name, job_id:, anomalies: @anomalies).deliver_now
      end

      @anomalies
    end
  end
end
