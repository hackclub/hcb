# frozen_string_literal: true

FactoryBot.define do
  factory :event_termination_request, class: "Event::TerminationRequest" do
    association :event
    association :requested_by, factory: :user
    reason { "Our project has wrapped up." }
  end
end
