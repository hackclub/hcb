# frozen_string_literal: true

FactoryBot.define do
  factory :canonical_pending_event_mapping do
    association :canonical_pending_transaction
    association :event

    # Mirror production's Ledger::Mapper so `event.ledger` (and therefore
    # Event#balance) sees this pending transaction. See FactoryLedgerMapping.
    after(:create) do |mapping|
      FactoryLedgerMapping.map_to_primary_ledger(mapping.canonical_pending_transaction)
    end
  end
end
