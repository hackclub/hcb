# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class DeleteDomain
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(domain:)
          @domain = domain
        end

        def run
          unless Rails.env.production?
            puts "☣️ In production, we would currently be starting deletion of the GSuite on Google Admin ☣️"
            ::GSuite::DeleteDomainUsersJob.set(wait: 1.minute).perform_later(domain: @domain, remote_org_unit_path: nil)
            return
          end
          # groups and users must be deleted to be able to delete domain
          DeleteGroupsOnDomain.new(domain: @domain).run
          gsuite = ::GSuite.find_by!(domain: @domain)
          gsuite.accounts.destroy_all
          # All jobs are queued one after another from within the delete domain users job
          # to ensure that the domain is deleted only after all users and org unit are deleted
          ::GSuite::DeleteDomainUsersJob.set(wait: 1.minute).perform_later(domain: @domain, remote_org_unit_path: gsuite.remote_org_unit_path)
        end

      end
    end
  end
end
