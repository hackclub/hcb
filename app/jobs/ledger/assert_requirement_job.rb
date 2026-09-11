# frozen_string_literal: true

class Ledger
  class AssertRequirementJob < ApplicationJob
    queue_as :low
    around_perform :log_anomalies

    class FailedAssertionError < StandardError; end
    class FailedJobError < StandardError; end

    def report_anomaly(message)
      @anomalies << message
      Rails.error.report(Ledger::AssertRequirementJob::FailedAssertionError.new(message))
    end

    private

    def log_anomalies
      @anomalies = []

      yield

      if @anomalies.any?
        Rails.error.report(Ledger::AssertRequirementJob::FailedJobError.new("#{self.class.name} failed with #{@anomalies.count} anomalies (#{job_id})"))
        AdminMailer.failed_assertion_job(job: self.class.name, job_id:, anomalies: @anomalies).deliver_now
      end

      @anomalies
    end

  end

end
