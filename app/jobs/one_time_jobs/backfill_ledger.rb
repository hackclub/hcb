# frozen_string_literal: true

module OneTimeJobs
  class BackfillLedger < ApplicationJob
    # This script should be idempotent and can be run multiple times safely.
    # It enqueues a BackfillLedgerEvent job for each event that has HcbCodes
    # needing backfill. Those jobs run on the throttled "metrics" queue to
    # avoid overloading the database.
    def perform
      # backfill_event_ledgers
      # backfill_card_grant_ledgers
      queue_ledger_item_jobs
    end

    def backfill_event_ledgers
      collection = Event.where.missing(:ledger)
      puts "Backfilling Ledger on #{collection.count} Events"

      collection.find_each do |event|
        event.create_ledger!(primary: true)
      end
    end

    def backfill_card_grant_ledgers
      collection = CardGrant.where.missing(:ledger)
      puts "Backfilling Ledger on #{collection.count} CardGrants"

      collection.find_each do |card_grant|
        card_grant.create_ledger!(primary: true)
      end
    end

    def queue_ledger_item_jobs
      Event.all.pluck(:id).each do |event_id|
        OneTimeJobs::BackfillLedgerEvent.perform_later(event_id)
      end
    end

  end
end
