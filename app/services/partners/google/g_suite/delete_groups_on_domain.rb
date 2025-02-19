# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class DeleteGroupsOnDomain
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(domain:)
          @domain = domain
        end

        def run
          unless Rails.env.production?
            puts "☣️ In production, we would currently be updating the GSuite on Google Admin ☣️"
            return
          end
          begin
            res = directory_client.list_groups(customer: gsuite_customer_id, domain: @domain)
            res.groups.each do |group|
              directory_client.delete_group(group.id)
            end
          rescue => e
            Rails.error.report(e)
            throw :abort
          end
        end

      end
    end
  end
end
