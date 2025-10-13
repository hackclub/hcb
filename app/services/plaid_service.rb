# frozen_string_literal: true

class PlaidService
  include Singleton

  def client_id
    Credentials.fetch(:PLAID, :CLIENT_ID)
  end

  def public_key
    Credentials.fetch(:PLAID, :PUBLIC_KEY)
  end

  def secret_key
    case env
    when "development"
      Credentials.fetch(:PLAID, :DEVELOPMENT_SECRET)
    when "sandbox"
      Credentials.fetch(:PLAID, :SANDBOX_SECRET)
    when "production"
      Credentials.fetch(:PLAID, :PRODUCTION_SECRET)
    end
  end

  def client_name
    "HCB"
  end

  # env to provide to Plaid Link integration
  def env
    "production"
  end

  def client
    configuration = ::Plaid::Configuration.new
    configuration.server_index = ::Plaid::Configuration::Environment[env]
    configuration.api_key["PLAID-CLIENT-ID"] = client_id
    configuration.api_key["PLAID-SECRET"] = secret_key

    api_client = ::Plaid::ApiClient.new(configuration)

    ::Plaid::PlaidApi.new(api_client)
  end

  def exchange_public_token(public_token)
    request = Plaid::ItemPublicTokenExchangeRequest.new(public_token:)
    client.item_public_token_exchange(request)
  end

end
