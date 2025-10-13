# frozen_string_literal: true

module Partners
  module Plaid
    module Shared
      module Client
        private

        def plaid_client
          configuration = ::Plaid::Configuration.new
          configuration.server_index = ::Plaid::Configuration::Environment[plaid_env]
          configuration.api_key["PLAID-CLIENT-ID"] = plaid_client_id
          configuration.api_key["PLAID-SECRET"] = plaid_secret

          api_client = ::Plaid::ApiClient.new(configuration)

          ::Plaid::PlaidApi.new(api_client)
        end

        def plaid_client_id
          Credentials.fetch(:PLAID, :CLIENT_ID)
        end

        def plaid_secret
          case plaid_env
          when "development"
            Credentials.fetch(:PLAID, :DEVELOPMENT_SECRET)
          when "sandbox"
            Credentials.fetch(:PLAID, :SANDBOX_SECRET)
          when "production"
            Credentials.fetch(:PLAID, :PRODUCTION_SECRET)
          end
        end

        def plaid_public_key
          Credentials.fetch(:PLAID, :PUBLIC_KEY)
        end

        def plaid_env
          "production"
        end
      end
    end
  end
end
