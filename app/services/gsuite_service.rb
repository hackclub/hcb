# frozen_string_literal: true

class GsuiteService
  include Singleton

  OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
  SCOPE = [
    Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER,
    Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_ORGUNIT,
    Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_DOMAIN
  ].freeze

  # this is a hack to work with the google library's requirement that tokens must be in files
  TOKEN_FILE = Tempfile.new("token")
  TOKEN_FILE << Credentials.fetch(:GSUITE, :TOKEN)
  TOKEN_FILE.rewind
  TOKEN_FILE.close

  def authorize
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id:, code:, base_url: OOB_URI
      )
    end
    credentials
  end

  def client
    service = Google::Apis::AdminDirectoryV1::DirectoryService.new
    service.client_options.application_name = "Hack Club Bank"
    service.client_options.log_http_requests = false
    service.authorization = authorize # calling the above method for authorization

    service
  end

  def get_gsuite_user(email)
    begin
      client.get_user(
        email,
        projection: "full"
      )
    rescue Google::Apis::ClientError
      nil
    end
  end

  def delete_gsuite_user(email)
    begin
      client.delete_user(email)
      true
    rescue Google::Apis::ClientError
      false
    end
  end

  # sets a GSuite user's password to something specified & forces them to change it on next login
  def reset_gsuite_user_password(email, password)
    update_user_struct = Google::Apis::AdminDirectoryV1::User.new(
      change_password_at_next_login: true,
      password:
    )
    client.update_user(email, update_user_struct)
  end

  def toggle_gsuite_user_suspension(email, suspend)
    update_user_struct = Google::Apis::AdminDirectoryV1::User.new(
      suspended: suspend
    )
    client.update_user(email, update_user_struct)
  end

  private

  def client_id
    @client_id ||= Google::Auth::ClientId.from_hash JSON.parse(Credentials.fetch(:GSUITE, :CLIENT_ID_JSON))
  end

  def token_store
    @token_store ||= Google::Auth::Stores::FileTokenStore.new file: TOKEN_FILE.path
  end

  def authorizer
    @authorizer ||= Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  end

  def user_id
    "default"
  end

end
