# frozen_string_literal: true

module GSuiteJob
  class CloseRemediedRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite::Revocation.find_each(batch_size: 100) do |revocation|
        if revocation.because_of_invalid_dns? && revocation.g_suite.verified?
          revocation.destroy!
        elsif revocation.because_of_accounts_inactive? && !revocation.g_suite.accounts_inactive?
          revocation.destroy!
        end
      end
    end

  end
end
