# frozen_string_literal: true

module GSuiteJob
  class TransitionExpiredRevocations < ApplicationJob
    queue_as :low

    def perform
      GSuite::Revocation.where("scheduled_at < ?", 12.hours.ago).find_each(batch_size: 100) do |revocation|
        revocation.mark_pending_revocation!
      end
    end

  end
end
