# frozen_string_literal: true

module Maintenance
  # Migrates historical HcbCode::Pin rows (from before Ledger::Item::Pin existed)
  # into a linked Ledger::Item::Pin, so both models are populated going forward.
  # New pins on either model self-link via HcbCode::Pin#sync_ledger_item_pin /
  # Ledger::Item::Pin#sync_hcb_code_pin; this task only backfills the gap.
  class BackfillLedgerItemPinsTask < MaintenanceTasks::Task
    class AnomalyError < StandardError; end

    def collection
      HcbCode::Pin.where(ledger_item_pin_id: nil)
    end

    def process(hcb_code_pin)
      ledger_item = hcb_code_pin.hcb_code&.ledger_item

      if ledger_item.nil?
        Rails.error.report AnomalyError.new("HcbCode::Pin #{hcb_code_pin.id} has no ledger_item to migrate to (hcb_code #{hcb_code_pin.hcb_code_id.inspect} has no ledger_item)")
        return
      end

      if ledger_item.primary_ledger&.event != hcb_code_pin.event
        Rails.error.report AnomalyError.new("HcbCode::Pin #{hcb_code_pin.id} was pinned for event #{hcb_code_pin.event_id}, but ledger_item #{ledger_item.id}'s current primary ledger event is #{ledger_item.primary_ledger&.event_id.inspect}")
      end

      # find_or_initialize_by makes this idempotent across reruns, and also covers the
      # (unlikely) case of two legacy pins on the same hcb_code sharing one ledger_item.
      ledger_item_pin = Ledger::Item::Pin.find_or_initialize_by(ledger_item: ledger_item)
      if ledger_item_pin.new_record?
        ledger_item_pin.skip_hcb_code_pin_sync = true
        # This is replaying already-accepted history, not a new pin action; don't
        # re-run today's pinnable?/max-pins-for-event validations against it.
        ledger_item_pin.save!(validate: false)
      end

      hcb_code_pin.update_column(:ledger_item_pin_id, ledger_item_pin.id)
    end

  end
end
