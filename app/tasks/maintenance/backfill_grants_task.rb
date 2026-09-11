# frozen_string_literal: true

module Maintenance
  # Creates one Grant per existing CardGrant. The grantable is the reimbursement
  # report for grants already accepted as a reimbursement, otherwise the card
  # grant itself (pending, card, canceled, and expired grants all keep pointing at
  # the CardGrant). Idempotent: a card grant whose grant already exists is skipped,
  # so the task is safe to re-run.
  class BackfillGrantsTask < MaintenanceTasks::Task
    def collection
      CardGrant.all
    end

    def process(card_grant)
      grantable = card_grant.reimbursement_report || card_grant
      return if Grant.exists?(grantable:)

      Grant.create!(
        grantable:,
        event: card_grant.event,
        user: card_grant.user,
        sent_by: card_grant.sent_by
      )
    end

  end
end
