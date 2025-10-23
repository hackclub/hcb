# frozen_string_literal: true

FactoryBot.define do
  factory :organizer_position do
    association :user
    association :event
    organizer_position_invite do
      association(:organizer_position_invite, event:, user:)
    end
  end
end
