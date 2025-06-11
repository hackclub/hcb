# frozen_string_literal: true

class GSuite
  class DeleteDomainUsersJob < ApplicationJob
    queue_as :default

    include Partners::Google::GSuite::Shared::DirectoryClient

    def perform(domain:, remote_org_unit_path:, times_queued: 1)
      unless Rails.env.production?
        puts "☣️ In production, we would currently be deleting the domain #{domain}'s users on Google Admin ☣️"
        DeleteOrgUnitJob.set(wait: 1.minute).perform_later(domain:, remote_org_unit_path:)
        return
      end

      begin
        Partners::Google::GSuite::DeleteUsersOnDomain.new(domain:).run
        DeleteOrgUnitJob.set(wait: 1.minute).perform_later(domain:, remote_org_unit_path:)
      rescue => e
        if times_queued < 3
          retry_job(wait: 2.minutes, domain:, remote_org_unit_path:, times_queued: times_queued + 1)
          return
        end
        Rails.error.report("Failed to delete GSuite domain #{domain}'s users after 3 attempts (pls do manually): #{e.message}\nBacktrace: #{e.backtrace}")
      end
    end

  end

end
