# frozen_string_literal: true

module GSuiteJob
  class InitiateRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite.where(revocation: nil).find_each(batch_size: 100) do |g_suite|
        next if g_suite.immune_to_revocation?

        if (g_suite.aasm_state == "verification_error")
          @g_suite.revocation = GSuite::Revocation.create!(g_suite: @g_suite, reason: :invalid_dns)
        elsif g_suite.accounts_inactive?
          @g_suite.revocation = GSuite::Revocation.create!(g_suite: @g_suite, reason: :accounts_inactive)
        end
      end
    end

  end
end
