# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    association :event
    sequence(:label) { |n| "Tag #{n}" }
    emoji { "🏷️" }
    color { "muted" }
  end
end
