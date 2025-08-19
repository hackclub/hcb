# frozen_string_literal: true

class GSuite
  class DeleteDomainJob < ApplicationJob
    queue_as :default

    include Partners::Google::GSuite::Shared::DirectoryClient

    retry_on Google::Apis::ClientError, attempts: 3, wait: 2.minutes do |job, e|
      Rails.error.report("Failed to delete GSuite domain #{domain} after 3 attempts (pls do manually): #{e.message}\nBacktrace: #{e.backtrace}")
    end

    def perform(domain:)
      unless Rails.env.production?
        puts "☣️ In production, we would currently be deleting the domain #{domain} on Google Admin ☣️"
        return
      end

      directory_client.delete_domain(gsuite_customer_id, domain)
    end

  end

end
