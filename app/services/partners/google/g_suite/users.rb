# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class Users
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(domain:)
          @domain = domain
        end

        def run
          directory_client.list_users(customer: gsuite_customer_id, domain: @domain, max_results: 500)
        end

      end
    end
  end
end
