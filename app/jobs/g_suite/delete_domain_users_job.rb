# frozen_string_literal: true

class GSuite
  class DeleteDomainUsersJob < ApplicationJob
    queue_as :default

    include Partners::Google::GSuite::Shared::DirectoryClient

    retry_on Google::Apis::ClientError, attempts: 3, wait: 2.minutes do |job, e|
      Rails.error.report("Failed to delete GSuite domain #{domain}'s users after 3 attempts (pls do manually): #{e.message}\nBacktrace: #{e.backtrace}")
    end

    def perform(domain:, remote_org_unit_path:)
      unless Rails.env.production?
        puts "☣️ In production, we would currently be deleting the domain #{domain}'s users on Google Admin ☣️"
        DeleteOrgUnitJob.set(wait: 1.minute).perform_later(domain:, remote_org_unit_path:)
        return
      end

      Partners::Google::GSuite::DeleteUsersOnDomain.new(domain:).run
      DeleteOrgUnitJob.set(wait: 1.minute).perform_later(domain:, remote_org_unit_path:)
    end

  end

end
