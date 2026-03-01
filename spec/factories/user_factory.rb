# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    after(:build) do |user|
      default_full_name = "#{user.first_name} #{user.last_name}"

      if user.full_name&.present? && user.full_name != default_full_name
        require "namae"
        namae_obj = Namae.parse(user.full_name).first
        user.first_name = (namae_obj&.given || namae_obj&.particle)&.split(" ")&.first || namae_obj&.family
        user.last_name = namae_obj&.family&.split(" ")&.last
      elsif user.full_name.blank?
        user.first_name = nil
        user.last_name = nil
      else
        user.full_name = default_full_name
      end
    end

    session_validity_preference { SessionsHelper::SESSION_DURATION_OPTIONS.fetch("3 days") }

    trait :make_admin do
      access_level { :admin }
    end
  end
end
