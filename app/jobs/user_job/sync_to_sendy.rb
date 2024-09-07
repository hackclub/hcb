# frozen_string_literal: true

module UserJob
  class SyncToSendy < ApplicationJob
    queue_as :default
    # Retry for 1 month (exponentially backoff)
    retry_on Exception, wait: :polynomially_longer, attempts: 26

    def perform(user_id)
      ::UserService::SyncToSendy.new(user_id:, dry_run: false).run
    end

  end
end
