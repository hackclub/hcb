# frozen_string_literal: true

module GSuiteJob
  class MarkVerifieds < ApplicationJob
    queue_as :default
    def perform
      GSuite.verifying.in_batches(of: 100) do |g_suites|
        g_suites.pluck(:id).each do |g_suite_id|
          begin
            ::GSuiteService::MarkVerified.new(g_suite_id:).run
          rescue => e
            Rails.error.report(e)
          end
        end
      end
    end

  end
end
