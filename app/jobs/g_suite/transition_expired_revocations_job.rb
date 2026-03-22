# frozen_string_literal: true

class GSuite
  class TransitionExpiredRevocationsJob < ApplicationJob
    queue_as :low

    def perform
      GSuite::Revocation.where("scheduled_at < ?", 1.day.ago).pending.find_each(batch_size: 100) do |revocation| # we wait for 1 day to allow for time zone differences
        if revocation.g_suite.immune_to_revocation?
          revocation.destroy!
          next
        end
        revocation.mark_revoked!
      end
    end

  end

end

module GSuiteJob
  TransitionExpiredRevocations = GSuite::TransitionExpiredRevocationsJob
end
