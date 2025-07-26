# frozen_string_literal: true

class CanonicalPendingTransactionMailerPreview < ActionMailer::Preview
  def notify_approved
    # @cpt = CanonicalPendingTransaction.stripe.last
    @cpt = CanonicalPendingTransaction.stripe.where("amount_cents < ?", -1_000_00).last

    CanonicalPendingTransactionMailer.with(
      canonical_pending_transaction_id: @cpt.id,
    ).notify_approved
  end

  def notify_declined
    # @cpt = CanonicalPendingTransaction.stripe.last
    @cpt = CanonicalPendingTransaction.stripe.where("amount_cents < ?", -1_000_00).last

    CanonicalPendingTransactionMailer.with(
      canonical_pending_transaction_id: @cpt.id,
    ).notify_declined
  end

  def notify_settled
    # @cpt = CanonicalPendingTransaction.stripe.last
    @cpt = CanonicalPendingTransaction.stripe.where("amount_cents < ?", -1_000_00).first
    @ct = @cpt.local_hcb_code.ct

    CanonicalPendingTransactionMailer.with(
      canonical_pending_transaction_id: @cpt.id,
      canonical_transaction_id: @ct.id
    ).notify_settled
  end

end
