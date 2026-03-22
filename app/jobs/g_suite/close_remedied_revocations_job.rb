# frozen_string_literal: true

class GSuite
  class CloseRemediedRevocationsJob < ApplicationJob
    queue_as :low

    def perform
      GSuite::Revocation.find_each(batch_size: 100) do |revocation|
        if (revocation.because_of_invalid_dns? && revocation.g_suite.verified?) ||
           (revocation.because_of_accounts_inactive? && !revocation.g_suite.accounts_inactive?) ||
           revocation.g_suite.immune_to_revocation?
          revocation.destroy!
        end
      end
    end

  end

end

module GSuiteJob
  CloseRemediedRevocations = GSuite::CloseRemediedRevocationsJob
end
