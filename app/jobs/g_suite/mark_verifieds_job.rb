# frozen_string_literal: true

class GSuite
  class MarkVerifiedsJob < ApplicationJob
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

module GSuiteJob
  MarkVerifieds = GSuite::MarkVerifiedsJob
end
