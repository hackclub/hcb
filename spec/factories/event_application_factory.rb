# frozen_string_literal: true

FactoryBot.define do
  factory :event_application, class: "Event::Application" do
    association :user
    name { Faker::Company.name }
  end
end
