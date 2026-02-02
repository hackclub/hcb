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
      # TODO: set HcbCode#ledger_item_id during backfill, and exclude from query below
      hcb_codes = HcbCode
                  .left_joins(:canonical_transactions, :canonical_pending_transactions)
                  .where("canonical_transactions.id IS NOT NULL OR canonical_pending_transactions.id IS NOT NULL")
                  .distinct
                  .includes(
                    :canonical_transactions,
                    :canonical_pending_transactions,
                    subledger: { card_grant: :ledger },
                    event: :ledger
                  )
                  .where.missing(:ledger_item)
                  .where(event_id: 183) # only backfill HQ for noe
      total = hcb_codes.count
      puts "Backfilling Ledger::Items from #{total} HcbCodes"

      processed = 0
      errors = 0
      hcb_codes.find_each do |hcb_code|
        begin
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
          hcb_code.update!(ledger_item: item)

          processed += 1
          if processed % 100 == 0
            puts "Processed #{processed} / #{total} HcbCodes (#{(processed.to_f / total * 100).round(1)}%)"
          end
        rescue => e
          errors += 1
          puts "ERROR: Failed to process HcbCode##{hcb_code.id} - #{e.class}: #{e.message}"
        end
      end

      puts "Completed! Processed #{processed} / #{total} HcbCodes (#{errors} errors)"
    end

  end
end
