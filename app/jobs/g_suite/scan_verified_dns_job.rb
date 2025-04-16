# frozen_string_literal: true

class GSuite
  class ScanVerifiedDnsJob < ApplicationJob
    queue_as :low

    def perform
      GSuite.verified.find_each(batch_size: 100) do |g_suite|
        GSuiteService::Verify.new(g_suite_id: g_suite.id).run
      end
    end

  end

end

module GSuiteJob
  ScanVerifiedDns = GSuite::ScanVerifiedDnsJob
end
