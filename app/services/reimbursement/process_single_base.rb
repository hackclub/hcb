# frozen_string_literal: true

module Reimbursement
  # Base class for processing a single reimbursement book transfer.
  # Subclasses must implement #record to return the payout record.
  class ProcessSingleBase
    def initialize(record_id:)
      @record_id = record_id
    end

    def run
      raise ArgumentError, "must be pending only" unless record.pending?

      ActiveRecord::Base.transaction do
        record.mark_in_transit!

        sender_bank_account_id = ColumnService::Accounts.id_of record.book_transfer_originating_account
        receiver_bank_account_id = ColumnService::Accounts.id_of record.book_transfer_receiving_account

        ColumnService.post "/transfers/book",
                           idempotency_key: record.public_id,
                           amount: record.amount_cents.abs,
                           currency_code: "USD",
                           sender_bank_account_id:,
                           receiver_bank_account_id:,
                           description: memo
      end

      true
    end

    private

    def memo
      "HCB-#{record.local_hcb_code.short_code}"
    end

    # Subclasses must override this method to return the payout record.
    def record
      raise NotImplementedError
    end
  end
end
