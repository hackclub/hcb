# frozen_string_literal: true

module GSuiteJob
  class InitiateRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite.where(immune_to_revocation: false)
            .where("g_suites.created_at < ?", 2.months.ago)
            .left_joins(:revocation)
            .where(g_suite_revocations: { id: nil })
            .find_each(batch_size: 100) do |g_suite|
        if g_suite.verification_error?
          GSuite::Revocation.create!(g_suite: @g_suite, reason: :invalid_dns)
        elsif g_suite.accounts_inactive?
          GSuite::Revocation.create!(g_suite: @g_suite, reason: :accounts_inactive)
        end
      end
    end

  end
end
