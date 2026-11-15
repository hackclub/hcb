# frozen_string_literal: true

class GSuite
  class DeleteOrgUnitJob < ApplicationJob
    queue_as :default

    include Partners::Google::GSuite::Shared::DirectoryClient

    retry_on Google::Apis::ClientError, attempts: 3, wait: 2.minutes do |job, e|
      Rails.error.report("Failed to delete GSuite org unit after 3 attempts (please do manually): #{e.message}\nBacktrace: #{e.backtrace}")
    end

    def perform(domain:, remote_org_unit_path:)
      unless Rails.env.production?
        puts "☣️ In production, we would currently be deleting the domain #{domain}'s org unit on Google Admin ☣️"
        DeleteDomainJob.set(wait: 1.minute).perform_later(domain:)
        return
      end

      begin
        Partners::Google::GSuite::DeleteOrgUnit.new(org_unit_path: remote_org_unit_path).run if remote_org_unit_path.present?
        DeleteDomainJob.set(wait: 1.minute).perform_later(domain:)
      rescue => e
        # If the org unit is not found, we can ignore it
        return if e.message.include?("Org unit not found")

        raise
      end
    end

  end

end
