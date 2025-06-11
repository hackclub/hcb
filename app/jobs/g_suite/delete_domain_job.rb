# frozen_string_literal: true

class GSuite
  class DeleteDomainJob < ApplicationJob
    queue_as :default

    include Partners::Google::GSuite::Shared::DirectoryClient

    def perform(domain:, times_queued: 1)
      unless Rails.env.production?
        puts "☣️ In production, we would currently be deleting the domain #{domain} on Google Admin ☣️"
        return
      end

      begin
        directory_client.delete_domain(gsuite_customer_id, domain)
      rescue => e
        if times_queued < 3
          retry_job(wait: 2.minutes, domain:, times_queued: times_queued + 1)
          return
        end
        Rails.error.report("Failed to delete GSuite domain #{domain} after 3 attempts (pls do manually): #{e.message}\nBacktrace: #{e.backtrace}")
      end
    end

  end

end
