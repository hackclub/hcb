# frozen_string_literal: true

module Maintenance
  # Copies existing HcbCodeTags onto their HcbCode's Ledger::Item as
  # Ledger::Item::Tags. Idempotent: re-running upserts on the
  # (ledger_item_id, tag_id) primary key, so already-copied rows are left
  # untouched.
  class BackfillLedgerItemTagsTask < MaintenanceTasks::Task
    def collection
      HcbCodeTag
        .where(hcb_code_id: HcbCode.where.not(ledger_item_id: nil))
        .includes(:hcb_code)
    end

    def process(hcb_code_tag)
      Ledger::Item::Tag.upsert(
        {
          ledger_item_id: hcb_code_tag.hcb_code.ledger_item_id,
          tag_id: hcb_code_tag.tag_id,
          created_at: hcb_code_tag.created_at,
          updated_at: hcb_code_tag.updated_at,
        },
        unique_by: [:ledger_item_id, :tag_id]
      )
    end

  end
end
