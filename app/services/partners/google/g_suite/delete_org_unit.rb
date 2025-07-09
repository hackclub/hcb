# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class DeleteOrgUnit
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(org_unit_path:)
          @org_unit_path = org_unit_path
        end

        def run
          directory_client.delete_org_unit(gsuite_customer_id, org_unit_path_without_leading_slash)
        end

        private

        def org_unit_path_without_leading_slash
          @org_unit_path.split("/").reject { |c| c.empty? }.join("/")
        end

      end
    end
  end
end
