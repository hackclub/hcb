# frozen_string_literal: true

module DisbursementService
  class Nightly
    def run
      return unless Disbursement.pending.present?

      Disbursement.pending.find_each(batch_size: 100) do |disbursement|
        raise ArgumentError, "must be a pending disbursement only" unless disbursement.pending?

        amount_cents = disbursement.amount
        memo = disbursement.transaction_memo

        if disbursement.destination_event.increase_account_id != disbursement.source_event.increase_account_id
          raise "DAF transfers not implemented yet"
        else
          # events are on the same Increase account

          # FS Main -> FS Operating
          ColumnService.post "/transfers/book",
                             amount: amount_cents,
                             currency_code: "USD",
                             sender_bank_account_id: ColumnService::Accounts::FS_MAIN,
                             receiver_bank_account_id: ColumnService::Accounts::FS_OPERATING,
                             description: memo

          # FS Operating -> FS Main
          ColumnService.post "/transfers/book",
                             amount: amount_cents,
                             currency_code: "USD",
                             sender_bank_account_id: ColumnService::Accounts::FS_OPERATING,
                             receiver_bank_account_id: ColumnService::Accounts::FS_MAIN,
                             description: memo
        end

        disbursement.mark_in_transit!
      end
    end

  end
end
