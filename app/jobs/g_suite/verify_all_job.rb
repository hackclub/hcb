# frozen_string_literal: true

class GSuite
  class VerifyAllJob < ApplicationJob
    queue_as :default
    def perform
      GSuite.verifying.in_batches(of: 100) do |g_suites|
        g_suites.pluck(:id).each do |g_suite_id|
          GSuiteService::Verify.new(g_suite_id:).run
        end
      end
    end

  end

end

module GSuiteJob
  VerifyAll = GSuite::VerifyAllJob
end
