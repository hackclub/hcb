# frozen_string_literal: true

module GSuiteJob
  class InitiateRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite.where(revocation_immunity: false)
            .where("created_at < ?", 2.months.ago)
            .missing(:revocation)
            .find_each(batch_size: 100) do |g_suite|
        if (g_suite.verification_error?)
          GSuite::Revocation.create!(g_suite: @g_suite, reason: :invalid_dns)
        elsif g_suite.accounts_inactive?
          GSuite::Revocation.create!(g_suite: @g_suite, reason: :accounts_inactive)
        end
      end
    end

  end
end
