# frozen_string_literal: true

module Maintenance
  # Copies existing HcbCodeTags onto their HcbCode's Ledger::Item as
  # Ledger::Item::Tags. Idempotent: pairs that already exist (from an earlier
  # run, or tagged on the ledger item since deploy) are skipped.
  #
  # Iterates HcbCodes rather than HcbCodeTags: hcb_codes_tags has a composite
  # primary key, and maintenance_tasks persists the cursor as a string, so an
  # array cursor breaks the query when the run resumes after an interruption.
  class BackfillLedgerItemTagsTask < MaintenanceTasks::Task
    def collection
      HcbCode
        .where.not(ledger_item_id: nil)
        .where(id: HcbCodeTag.select(:hcb_code_id))
        .includes(hcb_code_tags: :tag)
    end

    def process(hcb_code)
      hcb_code.hcb_code_tags.each do |hcb_code_tag|
        # Tag#hcb_code_tags has no `dependent:` and no foreign key, so deleted
        # tags leave orphaned rows behind. Nothing to copy for those.
        next if hcb_code_tag.tag.nil?

        # Idempotent and race-safe: an existing (ledger_item_id, tag_id) row — from
        # an earlier run or tagged since deploy — hits the unique index and is
        # suppressed instead of costing an extra existence check per row.
        suppress(ActiveRecord::RecordNotUnique) do
          Ledger::Item::Tag.create!(
            ledger_item_id: hcb_code.ledger_item_id,
            tag_id: hcb_code_tag.tag_id,
            created_at: hcb_code_tag.created_at,
            updated_at: hcb_code_tag.updated_at,
          )
        end
      end
    end

  end
end
