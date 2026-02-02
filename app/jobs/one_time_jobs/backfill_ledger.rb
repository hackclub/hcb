# frozen_string_literal: true

module OneTimeJobs
  class BackfillLedger < ApplicationJob
    # This script should be idempotent and can be run multiple times safely.
    def perform
      backfill_event_ledgers
      backfill_card_grant_ledgers
    end

    def backfill_event_ledgers
      collection = Event.missing(:ledger)
      puts "Backfilling Ledger on #{collection.count} Events"

      collection.find_each do |event|
        event.create_ledger!(primary: true)
      end
    end

    def backfill_card_grant_ledgers
      collection = CardGrant.missing(:ledger)
      puts "Backfilling Ledger on #{collection.count} CardGrants"

      collection.find_each do |card_grant|
        card_grant.create_ledger!(primary: true)
      end
    end

  end
end
