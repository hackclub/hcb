# frozen_string_literal: true

module OneTimeJobs
  class BackfillLedger < ApplicationJob
    BATCH_SIZE = 500

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
      hcb_codes_scope = HcbCode
                        .left_joins(:canonical_transactions, :canonical_pending_transactions)
                        .where("canonical_transactions.id IS NOT NULL OR canonical_pending_transactions.id IS NOT NULL")
                        .where.not(short_code: nil)
                        .distinct
                        .includes(
                          :canonical_transactions,
                          :canonical_pending_transactions,
                          subledger: { card_grant: :ledger },
                          event: :ledger
                        )
                        .where.missing(:ledger_item)

      total = hcb_codes_scope.count
      puts "Backfilling Ledger::Items from #{total} HcbCodes"

      processed = 0
      errors = 0

      hcb_codes_scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        now = Time.current
        item_attrs = []
        ledger_id_by_short_code = {}
        hcb_code_ids = []

        batch.each do |hcb_code|
          ledger = if hcb_code.subledger_id.present? && (card_grant = hcb_code.subledger&.card_grant)
                     card_grant.ledger
                   else
                     hcb_code.event&.ledger
                   end
          next unless ledger

          hcb_code_ids << hcb_code.id
          ledger_id_by_short_code[hcb_code.short_code] = ledger.id

          item_attrs << {
            short_code: hcb_code.short_code,
            amount_cents: hcb_code.amount_cents,
            memo: hcb_code.memo,
            date: hcb_code.date || hcb_code.created_at,
            marked_no_or_lost_receipt_at: hcb_code.marked_no_or_lost_receipt_at,
            created_at: now,
            updated_at: now
          }
        rescue => e
          errors += 1
          puts "ERROR: HcbCode##{hcb_code.id} (collect) - #{e.class}: #{e.message}"
        end

        next if item_attrs.empty?

        # Insert missing Ledger::Items; skip if already present (idempotent).
        # amount_cents is a placeholder — write_amount_cents! recalculates below.
        Ledger::Item.insert_all(item_attrs)

        short_codes = item_attrs.map { |a| a[:short_code] }
        items_by_short_code = Ledger::Item.where(short_code: short_codes).index_by(&:short_code)

        mapping_attrs = ledger_id_by_short_code.filter_map do |short_code, ledger_id|
          next unless (item = items_by_short_code[short_code])

          { ledger_id:, ledger_item_id: item.id, on_primary_ledger: true, created_at: now, updated_at: now }
        end

        Ledger::Mapping.insert_all(mapping_attrs) if mapping_attrs.any?

        # Link canonical transactions to their ledger items in bulk.
        id_list = hcb_code_ids.join(",")
        connection = ActiveRecord::Base.connection

        connection.execute(<<~SQL)
          UPDATE canonical_transactions
          SET ledger_item_id = ledger_items.id
          FROM hcb_codes
          JOIN ledger_items ON ledger_items.short_code = hcb_codes.short_code
          WHERE canonical_transactions.hcb_code = hcb_codes.hcb_code
            AND hcb_codes.id IN (#{id_list})
        SQL

        connection.execute(<<~SQL)
          UPDATE canonical_pending_transactions
          SET ledger_item_id = ledger_items.id
          FROM hcb_codes
          JOIN ledger_items ON ledger_items.short_code = hcb_codes.short_code
          WHERE canonical_pending_transactions.hcb_code = hcb_codes.hcb_code
            AND hcb_codes.id IN (#{id_list})
        SQL

        # Recalculate each item's amount_cents now that transactions are linked.
        items_by_short_code.each_value(&:write_amount_cents!)

        # Stamp hcb_codes.ledger_item_id in bulk.
        connection.execute(<<~SQL)
          UPDATE hcb_codes
          SET ledger_item_id = ledger_items.id
          FROM ledger_items
          WHERE hcb_codes.short_code = ledger_items.short_code
            AND hcb_codes.id IN (#{id_list})
        SQL

        processed += batch.size
        puts "Processed #{processed} / #{total} (#{(processed.to_f / total * 100).round(1)}%)"
      end

      puts "Completed! Processed #{processed} / #{total} (#{errors} errors)"
    end

  end
end
