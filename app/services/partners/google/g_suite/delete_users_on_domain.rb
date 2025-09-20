# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class DeleteUsersOnDomain
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
            res = directory_client.list_users(customer: gsuite_customer_id, domain: @domain, max_results: 500)
            # we use a safe navigation operator here because res.users could potentially still be nil
            # despite the list_users call not returning an error
            res.users&.each do |user|
              directory_client.delete_user(user.id)
            end
          rescue => e
            return if e.message.include?("Domain not found")

            Rails.error.report(e)
            raise e
          end
        end

      end
    end
  end
end
