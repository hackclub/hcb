# frozen_string_literal: true

class PlaidService
  include Singleton

  def client_id
    Rails.application.credentials.plaid[:client_id]
  end

  def public_key
    Rails.application.credentials.plaid[:public_key]
  end

  def secret_key
    case env
    when "development"
      Rails.application.credentials.plaid[:development_secret]
    when "sandbox"
      Rails.application.credentials.plaid[:sandbox_secret]
    when "production"
      Rails.application.credentials.plaid[:production_secret]
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
