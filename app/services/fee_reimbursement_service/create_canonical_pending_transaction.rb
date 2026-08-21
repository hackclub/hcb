# frozen_string_literal: true

module FeeReimbursementService
  class CreateCanonicalPendingTransaction
    def initialize(fee_reimbursement_id:)
      @fee_reimbursement_id = fee_reimbursement_id
    end

    # Idempotent: safe to re-run (e.g. from the nightly) — it no-ops once the
    # fee reimbursement already has its raw pending transaction, skips
    # zero-amount reimbursements (which move no money and get no topup), and
    # skips reimbursements whose top-up has already settled as a real
    # CanonicalTransaction. That last case matters for old, backfilled
    # reimbursements: their money already moved and reconciled months/years
    # ago, so inventing a fresh "pending" leg for them now would never settle
    # (nothing ever maps a CPT back to a CT that already exists) and, worse,
    # can land on a different HcbCode/Ledger::Item than the one the real
    # settled transaction lives on — see FeeReimbursement#settled_fee_reimbursement_transaction.
    def run
      existing = fee_reimbursement.raw_pending_fee_reimbursement_transaction
      return existing.canonical_pending_transaction if existing.present?
      return if fee_reimbursement.amount.to_i.zero?
      return if fee_reimbursement.settled_fee_reimbursement_transaction.present?

      ActiveRecord::Base.transaction do
        rpfrt = fee_reimbursement.create_raw_pending_fee_reimbursement_transaction!(
          date_posted: (fee_reimbursement.processed_at || Time.current).to_date,
          amount_cents: -fee_reimbursement.amount
        )

        canonical_pending_transaction = CanonicalPendingTransaction.create!(
          date: rpfrt.date,
          amount_cents: rpfrt.amount_cents,
          memo: rpfrt.memo,
          raw_pending_fee_reimbursement_transaction: rpfrt
        )
        # Creating the CPT automatically creates a Ledger::Item and auto-maps it

        TransactionCategoryService
          .new(model: canonical_pending_transaction)
          .set!(
            slug: "stripe-fee-reimbursements",
            assignment_strategy: :automatic
          )

        # Fee reimbursements map to Hack Club Bank (not the org's event, which is
        # what FeeReimbursement#event returns) — matching how the settled
        # HCB-900 code is mapped.
        CanonicalPendingEventMapping.create!(
          event: Event.find(::EventMappingEngine::EventIds::HACK_CLUB_BANK),
          canonical_pending_transaction:
        )

        canonical_pending_transaction
      end
    end

    private

    def fee_reimbursement
      @fee_reimbursement ||= FeeReimbursement.find(@fee_reimbursement_id)
    end

  end
end
