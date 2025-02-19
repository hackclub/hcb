# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class CheckDomainForInactivity
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(domain:)
          @domain = domain
        end

        def run
          unless Rails.env.production?
            puts "☣️ In production, we would currently be updating the GSuite on Google Admin ☣️"
            # return false
          end
          begin
            res = directory_client.list_users(customer: gsuite_customer_id, domain: @domain, max_results: 500)
            res_count = res.users.count
            inactive_accounts = []
            res.users.each do |user|
              if user.is_admin
                res_count -= 1
                next
              end
              user_last_login = directory_client.get_user(user.id).last_login_time
              if user_last_login.nil? || user_last_login < 6.months.ago
                inactive_accounts << user
              end
            end
            if inactive_accounts.count == res_count
              return true
            end

            false
          rescue => e
            Rails.error.report(e)
            throw :abort
          end
        end

      end
    end
  end
end
