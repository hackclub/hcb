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

    def amount
      disbursement.amount.abs
    end

    def subledger
      disbursement.destination_subledger
    end

    def transaction_category
      disbursement.destination_transaction_category
    end

  end

end
