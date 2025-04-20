# frozen_string_literal: true

module GSuiteJob
  class TransitionExpiredRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite::Revocation.where("scheduled_at < ?", 12.hours.ago).find_each(batch_size: 100) do |revocation|
        if revocation.g_suite.immune_to_revocation?
          revocation.destroy!
          next
        end
        revocation.mark_revoked!
      end
    end

  end
end
