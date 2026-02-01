# frozen_string_literal: true

class Disbursement
  class Outgoing
    include Base

    def hcb_code
      disbursement.outgoing_hcb_code
    end

    def event
      disbursement.source_event
    end

    def amount
      -disbursement.amount
    end

    def subledger
      disbursement.source_subledger
    end

    def card_grant
      subledger&.card_grant
    end

    def transaction_category
      disbursement.source_transaction_category
    end

  end

end
