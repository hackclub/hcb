# frozen_string_literal: true

class Disbursement
  class Base < SimpleDelegator
    def initialize(disbursement)
      raise ArgumentError, "Expected Disbursement" unless disbursement.is_a?(Disbursement)

      super(disbursement)
    end

    def disbursement
      __getobj__
    end

    # Override to use wrapper's specific hcb_code
    def canonical_transactions
      @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
    end

    def canonical_pending_transactions
      @canonical_pending_transactions ||= CanonicalPendingTransaction.where(hcb_code:)
    end

    def pending_expired?
      local_hcb_code.has_pending_expired?
    end

    def transaction_memo
      "HCB-#{local_hcb_code.short_code}"
    end

    # Follow existing pattern: hcb_code returns string, local_hcb_code returns HcbCode record
    def local_hcb_code
      @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
    end

    # Abstract methods - subclasses must implement
    def hcb_code = raise(NotImplementedError)
    def event = raise(NotImplementedError)
  end
end
