# frozen_string_literal: true

module Maintenance
  # Moves the comments left on an HcbCode onto the code's Ledger::Item
  # (#14105). Codes with no ledger item keep their comments.
  #
  # Each code's comments, soft-deleted ones included, move in one UPDATE that
  # bypasses callbacks: saving a comment would touch the item (and so map! it),
  # record a PaperTrail version that Comment#edited? shows as an edit, and log
  # a PublicActivity per comment. Idempotent: a code whose comments have moved
  # drops out of the collection, and re-running after the final deploy picks
  # up stragglers written by old pods during the rollout.
  class BackfillLedgerItemCommentsTask < MaintenanceTasks::Task
    def collection
      HcbCode
        .where.not(ledger_item_id: nil)
        .where(id: Comment.with_deleted.where(commentable_type: "HcbCode").select(:commentable_id))
    end

    def process(hcb_code)
      Comment.with_deleted
             .where(commentable_type: "HcbCode", commentable_id: hcb_code.id)
             .update_all(commentable_type: "Ledger::Item", commentable_id: hcb_code.ledger_item_id)
    end

  end
end
