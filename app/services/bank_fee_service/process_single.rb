# frozen_string_literal: true

module BankFeeService
  class ProcessSingle
    def initialize(bank_fee_id:)
      @bank_fee_id = bank_fee_id
    end

    def run
      raise ArgumentError, "must be a pending bank fee only" unless bank_fee.pending?

      ActiveRecord::Base.transaction do
        bank_fee.mark_in_transit!

        sender_bank_account_id = ColumnService::Accounts.id_of bank_fee.book_transfer_originating_account
        receiver_bank_account_id = ColumnService::Accounts.id_of bank_fee.book_transfer_receiving_account

        ColumnService.post "/transfers/book",
                           idempotency_key: bank_fee.public_id,
                           amount: amount_cents.abs,
                           currency_code: "USD",
                           sender_bank_account_id:,
                           receiver_bank_account_id:,
                           description: memo
      end

      true
    end

    private

    def amount_cents
      bank_fee.amount_cents
    end

    def memo
      "HCB-#{local_hcb_code.short_code}"
    end

    def local_hcb_code
      @local_hcb_code ||= bank_fee.local_hcb_code
    end

    def bank_fee
      @bank_fee ||= BankFee.pending.find(@bank_fee_id)
    end

  end
end
