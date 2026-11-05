# frozen_string_literal: true

module Maintenance
  # One-time backfill: migrates legacy HcbCode::Pin records (hcb_code_pins
  # table) into Ledger::Mapping#pinned_at, preserving each pin's original
  # creation time. Run once after deploying Ledger::Item::Pin.
  class BackfillLedgerItemPinsTask < MaintenanceTasks::Task
    def collection
      HcbCode::Pin.all
    end

    def process(pin)
      # Only the primary mapping for a ledger item can be pinned — find_by
      # without on_primary_ledger could otherwise return a non-primary
      # mapping (e.g. the other side of a transfer) and fail validation.
      mapping = pin.hcb_code&.ledger_item&.primary_mapping
      return if mapping.nil?

      mapping.update!(pinned_at: pin.created_at)
    end

  end
end
