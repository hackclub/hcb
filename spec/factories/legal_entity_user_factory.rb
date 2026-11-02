# frozen_string_literal: true

FactoryBot.define do
  factory :legal_entity_user do
    association :legal_entity, :business
    user { create(:user) }
  end
end
