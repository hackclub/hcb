# frozen_string_literal: true

require "google/apis/admin_directory_v1"
require "googleauth"
require "googleauth/stores/file_token_store"

TOKEN_FILE = Tempfile.new("token")
TOKEN_PATH = TOKEN_FILE.path

OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
SCOPE = [Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER, Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_ORGUNIT].freeze

APP_DATA = "REDACTED"

client_id = Google::Auth::ClientId.from_hash JSON.parse(APP_DATA)
token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH

authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store

user_id = "default"

url = authorizer.get_authorization_url base_url: OOB_URI
puts "Open the following URL in the browser and enter the " \
     "resulting code after authorization:\n" + url
code = gets
credentials = authorizer.get_and_store_credentials_from_code(
  user_id:, code:, base_url: OOB_URI
)

TOKEN_FILE.rewind
token = File.read(TOKEN_PATH)

puts "------ COPY AND PASTE THE EXACT TEXT BELOW INTO RAILS CREDENTIALS (replace the current GSuite content that's there if needed) ------"

puts "gsuite:
  client_id_json: '#{APP_DATA}'
  token: #{token.gsub("\'", "").sub("---\ndefault: ", "'---\n    \n    default: ''").sub("}\n", "}")}'''"

TOKEN_FILE.close
TOKEN_FILE.unlink
