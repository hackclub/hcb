# frozen_string_literal: true

class Disbursement
  class Incoming
    include Base

    def hcb_code
      disbursement.incoming_hcb_code
    end

    def event
      disbursement.destination_event
    end

    delegate :amount, to: :disbursement

    def subledger
      disbursement.destination_subledger
    end

    def transaction_category
      disbursement.destination_transaction_category
    end

    def canonical_transactions
      @canonical_transactions ||= disbursement.local_hcb_code.canonical_transactions.where("amount_cents > 0")
    end

    def canonical_pending_transactions
      @canonical_pending_transactions ||= disbursement.local_hcb_code.canonical_pending_transactions.where("amount_cents > 0")
    end

    def pending_expired?
      canonical_pending_transactions.pending_expired.any?
    end

  end

end
