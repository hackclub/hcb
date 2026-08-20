# frozen_string_literal: true

module Maintenance
  # Comments on an HcbCode with no ledger_item have nowhere else to surface
  # (a ledger_item may never exist, e.g. an invoice that's never paid). As of
  # this writing every such orphan is invoice-related, so move those
  # comments onto the Invoice itself instead — a stable home that exists
  # independent of whether/when the invoice is ever paid, and that now
  # participates in shared_commentable the same way Disbursement does.
  #
  # Includes soft-deleted comments (Comment.with_deleted) so a later restore
  # doesn't resurrect one still pointed at the old commentable.
  class BackfillOrphanedInvoiceCommentsTask < MaintenanceTasks::Task
    def collection
      Comment
        .with_deleted
        .where(commentable_type: "HcbCode")
        .where(commentable_id: HcbCode.where(ledger_item_id: nil).select(:id))
    end

    def process(comment)
      hcb_code = comment.commentable
      return unless hcb_code.invoice?

      invoice = hcb_code.invoice
      return if invoice.nil?

      comment.update!(commentable: invoice)
    end

  end
end
