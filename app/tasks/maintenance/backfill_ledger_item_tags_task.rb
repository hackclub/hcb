# frozen_string_literal: true

module Maintenance
  # Copies existing HcbCodeTags onto their HcbCode's Ledger::Item as
  # Ledger::Item::Tags. Idempotent: pairs that already exist (from an earlier
  # run, or tagged on the ledger item since deploy) are skipped.
  class BackfillLedgerItemTagsTask < MaintenanceTasks::Task
    def collection
      HcbCodeTag
        .where(hcb_code_id: HcbCode.where.not(ledger_item_id: nil))
        .includes(:hcb_code)
    end

    def process(hcb_code_tag)
      # Idempotent and race-safe: an existing (ledger_item_id, tag_id) row — from
      # an earlier run or tagged since deploy — hits the unique index and is
      # suppressed instead of costing an extra existence check per row.
      suppress(ActiveRecord::RecordNotUnique) do
        Ledger::Item::Tag.create!(
          ledger_item_id: hcb_code_tag.hcb_code.ledger_item_id,
          tag_id: hcb_code_tag.tag_id,
          created_at: hcb_code_tag.created_at,
          updated_at: hcb_code_tag.updated_at,
        )
      end
    end

  end
end
