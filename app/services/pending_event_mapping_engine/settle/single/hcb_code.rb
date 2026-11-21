# frozen_string_literal: true

module PendingEventMappingEngine
  module Settle
    module Single
      # Settles a CanonicalTransaction against the unsettled
      # CanonicalPendingTransaction that shares its HCB code. This is the
      # single-transaction form of the HCB code based settlers in
      # PendingEventMappingEngine::Settle (OutgoingAch, BankFeeHcbCode,
      # DonationHcbCode, InvoiceHcbCode, *DisbursementHcbCode) and the
      # `cpt.local_hcb_code.ct` lookups in PendingEventMappingEngine::Nightly.
      class HcbCode
        def initialize(canonical_transaction:)
          @canonical_transaction = canonical_transaction
        end

        def run
          return if hcb_code.nil? || hcb_code.unknown?

          cpt = unsettled_canonical_pending_transactions.order(:id).first
          return if cpt.nil?

          CanonicalPendingTransactionService::Settle.new(
            canonical_transaction: @canonical_transaction,
            canonical_pending_transaction: cpt
          ).run!

          # Mirrors PendingEventMappingEngine::Nightly#settle_canonical_pending_wire!
          cpt.wire.mark_deposited! if cpt.wire&.may_mark_deposited?

          cpt
        end

        private

        def hcb_code
          # The association may have been cached as nil before `write_hcb_code`
          # ran in the after_create callback.
          @hcb_code ||= ::HcbCode.find_by(hcb_code: @canonical_transaction.hcb_code) if @canonical_transaction.hcb_code.present?
        end

        def unsettled_canonical_pending_transactions
          cpts = hcb_code.canonical_pending_transactions.unsettled

          # Both sides of a disbursement are grouped under the same Disbursement,
          # so match on amount like the *DisbursementHcbCode settlers do.
          if hcb_code.outgoing_disbursement? || hcb_code.incoming_disbursement?
            cpts = cpts.where(amount_cents: @canonical_transaction.amount_cents)
          end

          cpts
        end

      end
    end
  end
end
