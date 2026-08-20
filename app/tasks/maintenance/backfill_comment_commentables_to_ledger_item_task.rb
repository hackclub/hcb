# frozen_string_literal: true

module Maintenance
  # Part of migrating comments from HcbCode to Ledger::Item. Moves every
  # comment still attached to an HcbCode over to that HcbCode's Ledger::Item.
  #
  # Skips HcbCodes with no ledger_item (a known, small set as of this writing
  # — see Maintenance::BackfillOrphanedInvoiceCommentsTask) — their comments
  # stay on the HcbCode for now.
  #
  # Includes soft-deleted comments (Comment.with_deleted) so a later restore
  # doesn't resurrect one still pointed at the old commentable.
  #
  # process uses a normal `update!` rather than a bulk `update_all` so the
  # existing `belongs_to :commentable, touch: true` on Comment fires per
  # record, which touches the new Ledger::Item and refreshes its cached
  # comment counts as a side effect — no separate recount pass needed.
  class BackfillCommentCommentablesToLedgerItemTask < MaintenanceTasks::Task
    def collection
      Comment
        .with_deleted
        .where(commentable_type: "HcbCode")
        .where(commentable_id: HcbCode.where.not(ledger_item_id: nil).select(:id))
    end

    def process(comment)
      ledger_item_id = comment.commentable.ledger_item_id
      return if ledger_item_id.nil?

      comment.update!(commentable_type: "Ledger::Item", commentable_id: ledger_item_id)
    end

  end
end
