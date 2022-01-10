# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class CreateDomain
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(domain:)
          @domain = domain
        end

        def run
          directory_client.insert_domain(gsuite_customer_id, domains_object)
        end

        private

        def domains_object
          ::Google::Apis::AdminDirectoryV1::Domains.new(domain_name: @domain, is_primary: false)
        end

      end
    end
  end
end
