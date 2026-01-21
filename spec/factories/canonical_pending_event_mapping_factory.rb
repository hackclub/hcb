# frozen_string_literal: true

FactoryBot.define do
  factory :canonical_pending_event_mapping do
    association :canonical_pending_transaction
    association :event
  end
end
