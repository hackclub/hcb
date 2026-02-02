# frozen_string_literal: true

module OneTimeJobs
  class BackfillLedger < ApplicationJob
    # This script should be idempotent and can be run multiple times safely.
    def perform
      backfill_event_ledgers
      backfill_card_grant_ledgers
      backfill_ledger_items
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

    def backfill_ledger_items
      hcb_codes = HcbCode
                  .includes(
                    :canonical_transactions,
                    :canonical_pending_transactions,
                    subledger: { card_grant: :ledger },
                    event: :ledger
                  ).where.not(canonical_transactions: [], canonical_pending_transactions: [])
      total = hcb_codes.count
      puts "Backfilling Ledger::Items from #{total} HcbCodes"

      processed = 0
      hcb_codes.find_each do |hcb_code|
        if hcb_code.subledger_id.present? && (card_grant = hcb_code.subledger&.card_grant)
          ledger = card_grant.ledger
        else
          ledger = hcb_code.event&.ledger
        end
        next unless ledger

        item = Ledger::Item.find_or_create_by!(short_code: hcb_code.short_code) do |li|
          li.amount_cents = hcb_code.amount_cents
          li.memo = hcb_code.memo
          li.date = hcb_code.date || hcb_code.created_at
          li.marked_no_or_lost_receipt_at = hcb_code.marked_no_or_lost_receipt_at
        end

        Ledger::Mapping.find_or_create_by!(ledger:, ledger_item: item) do |mapping|
          mapping.on_primary_ledger = true
        end

        hcb_code.canonical_transactions.update_all(ledger_item_id: item.id)
        hcb_code.canonical_pending_transactions.update_all(ledger_item_id: item.id)

        item.reload

        item.write_amount_cents!

        processed += 1
        if processed % 100 == 0
          puts "Processed #{processed} / #{total} HcbCodes (#{(processed.to_f / total * 100).round(1)}%)"
        end
      end

      puts "Completed! Processed #{processed} / #{total} HcbCodes"
    end

  end
end
