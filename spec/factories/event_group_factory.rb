# frozen_string_literal: true

FactoryBot.define do
  factory(:event_group, class: "Event::Group") do
    name { Faker::Adjective.positive }
    association(:user)
  end
end
