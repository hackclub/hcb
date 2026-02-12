# frozen_string_literal: true

Hashid::Rails.configure do |config|
  config.salt = Credentials.fetch(:HASHID_SALT)
end
