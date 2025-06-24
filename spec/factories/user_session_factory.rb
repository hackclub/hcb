# frozen_string_literal: true

FactoryBot.define do
  factory :user_session do
    association :user
    expiration_at { Time.now + 7.days.to_i }
  end
end
