# frozen_string_literal: true

FactoryBot.define do
  factory :tax_form, class: "Tax::Form" do
    association :legal_entity
    external_service { :taxbandits }
    aasm_state { :pending }

    trait :manual do
      external_service { :manual }
    end

    trait :sent do
      aasm_state { :sent }
      sent_at { Time.current }
      external_id { "sub_#{SecureRandom.hex(4)}" }
    end

    trait :completed do
      aasm_state { :completed }
      sent_at { 1.day.ago }
      completed_at { Time.current }
      external_id { "sub_#{SecureRandom.hex(4)}" }
      form_type { :W9 }
      # Match the legal entity by default: a completed form of the wrong entity type
      # is a filing mistake that makes the entity unpayable. Override explicitly to
      # exercise that path.
      entity_type { legal_entity.entity_type }
    end
  end
end
