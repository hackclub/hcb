# frozen_string_literal: true

FactoryBot.define do
  factory :illegal_entity do
    entity_type { :business }

    trait :person do
      entity_type { :person }
    end

    trait :business do
      entity_type { :business }
    end
  end
end
