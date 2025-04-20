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
          if Rails.env.production?
            puts "☣️ In production, we would currently be updating the GSuite on Google Admin ☣️"
            return
          end
          # groups and users must be deleted to be able to delete domain
          DeleteGroupsOnDomain.new(domain: @domain).run
          DeleteUsersOnDomain.new(domain: @domain).run
          directory_client.delete_domain(gsuite_customer_id, @domain)
        end

      end
    end
  end
end
