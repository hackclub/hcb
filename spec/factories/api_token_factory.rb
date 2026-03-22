# frozen_string_literal: true

FactoryBot.define do
  factory(:api_token) do
    association(:user)
    token { ApiToken.generate }
    expires_in { 5.minutes }
  end
end
