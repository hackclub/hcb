# frozen_string_literal: true

class Disbursement
  class Outgoing
    include Base

    def amount
      -disbursement.amount
    end

    def hcb_code
      disbursement.outgoing_hcb_code
    end

    def event
      disbursement.source_event
    end

    def counterparty_event
      disbursement.destination_event
    end

    def subledger
      disbursement.source_subledger
    end

    def counterparty_subledger
      disbursement.destination_subledger
    end

    def counterparty
      disbursement.incoming_disbursement
    end

    def transaction_category
      disbursement.source_transaction_category
    end

  end

end
