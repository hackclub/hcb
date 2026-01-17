# frozen_string_literal: true

FactoryBot.define do
  factory :user_session, class: "User::Session" do
    association :user
    expiration_at { 7.days.from_now }
    session_token { SecureRandom.urlsafe_base64 }
  end
end
