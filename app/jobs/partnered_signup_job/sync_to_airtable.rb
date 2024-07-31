# frozen_string_literal: true

module PartneredSignupJob
  class SyncToAirtable < ApplicationJob
    queue_as :low
    # Retry for 1 month (exponentially backoff)
    retry_on Exception, wait: :polynomially_longer, attempts: 26

    def perform(partnered_signup_id:)
      ::PartneredSignupService::SyncToAirtable.new(partnered_signup_id:).run
    end

  end
end
