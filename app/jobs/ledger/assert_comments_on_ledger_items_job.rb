# frozen_string_literal: true

class Ledger
  # A transaction's comments live on its Ledger::Item (#14105). A comment still
  # on an HcbCode that has a ledger item hasn't been moved there, which
  # Maintenance::BackfillLedgerItemCommentsTask does. Reported as a single
  # anomaly rather than one per comment: an unrun backfill would otherwise
  # report every comment ever left on a transaction.
  class AssertCommentsOnLedgerItemsJob < AssertRequirementJob
    def perform
      stale = Comment.with_deleted
                     .where(commentable_type: "HcbCode")
                     .joins("JOIN hcb_codes ON hcb_codes.id = comments.commentable_id")
                     .where.not(hcb_codes: { ledger_item_id: nil })

      count = stale.count
      return if count.zero?

      report_anomaly "#{count} comments are on an HcbCode that has a ledger item (e.g. Comment #{stale.order(:id).limit(5).pluck(:id).join(", ")}); run Maintenance::BackfillLedgerItemCommentsTask"
    end

  end

end
