# frozen_string_literal: true

module GSuiteJob
  class InitiateRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite.where(revocation: nil).find_each(batch_size: 100) do |g_suite|
        if (g_suite.aasm_state == "verification_error")
          GSuiteService::CreateRevocation.new(g_suite_id: g_suite.id, reason: :dns).run
        elsif inactive?(domain: g_suite.domain)
          GSuiteService::CreateRevocation.new(g_suite_id: g_suite.id, reason: :inactivity).run
        end
      end
    end

    def inactive?(domain:)
      Partners::Google::GSuite::CheckDomainForInactivity.new(domain:).run
    end

  end
end
