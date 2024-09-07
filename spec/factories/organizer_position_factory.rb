# frozen_string_literal: true

FactoryBot.define do
  factory :organizer_position do
    association :user
    association :event
    association :organizer_position_invite
  end
end
