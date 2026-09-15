# frozen_string_literal: true

module Maintenance
  # Copies existing HcbCodeTags onto their HcbCode's Ledger::Item as
  # Ledger::Item::Tags. Idempotent: re-running upserts on the
  # (ledger_item_id, tag_id) primary key, so already-copied rows are left
  # untouched.
  #
  # We iterate over HcbCode (integer PK) rather than the HcbCodeTag join
  # (composite PK) so job-iteration can cursor cleanly, and copy every tag
  # for a code in one upsert.
  class BackfillLedgerItemTagsTask < MaintenanceTasks::Task
    def collection
      HcbCode
        .where.not(ledger_item_id: nil)
        .where(id: HcbCodeTag.select(:hcb_code_id))
    end

    def process(hcb_code)
      rows = hcb_code.hcb_code_tags.map do |hcb_code_tag|
        {
          ledger_item_id: hcb_code.ledger_item_id,
          tag_id: hcb_code_tag.tag_id,
          created_at: hcb_code_tag.created_at,
          updated_at: hcb_code_tag.updated_at,
        }
      end

      return if rows.empty?

      Ledger::Item::Tag.upsert_all(rows, unique_by: [:ledger_item_id, :tag_id])
    end

  end
end
