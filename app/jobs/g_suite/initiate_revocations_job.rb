# frozen_string_literal: true

class GSuite
  class InitiateRevocationsJob < ApplicationJob
    queue_as :low

    def perform
      GSuite.where(immune_to_revocation: false)
            .where("g_suites.created_at < ?", 2.months.ago)
            .where.missing(:revocation)
            .find_each(batch_size: 100) do |g_suite|
        if g_suite.verification_error? || g_suite.configuring?
          g_suite.build_revocation({ reason: :invalid_dns }).save!
        elsif g_suite.accounts_inactive?
          g_suite.build_revocation({ reason: :accounts_inactive }).save!
        end
      end
    end

  end

end

module GSuiteJob
  InitiateRevocations = GSuite::InitiateRevocationsJob
end
