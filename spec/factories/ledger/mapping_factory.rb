# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_mapping, class: "Ledger::Mapping" do
    association :ledger
    association :ledger_item, factory: :ledger_item

    on_primary_ledger { false }

    trait :on_primary do
      on_primary_ledger { true }
    end
  end
end
