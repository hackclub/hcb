# frozen_string_literal: true

module PendingTransactionEngine
  module CanonicalPendingTransactionService
    module Import
      class BankFee
        def run
          raw_pending_bank_fee_transactions_ready_for_processing.find_each(batch_size: 100) do |rpit|

            ActiveRecord::Base.transaction do
              attrs = {
                date: rpit.date,
                memo: rpit.memo,
                amount_cents: rpit.amount_cents,
                raw_pending_bank_fee_transaction_id: rpit.id,
                fronted: rpit.amount_cents.positive?,
                fee_waived: true
              }
              ct = ::CanonicalPendingTransaction.create!(attrs)
            end

          end
        end

        private

        def raw_pending_bank_fee_transactions_ready_for_processing
          @raw_pending_bank_fee_transactions_ready_for_processing ||= begin
            return RawPendingBankFeeTransaction.all if previously_processed_raw_pending_bank_fee_transactions_ids.length < 1

            RawPendingBankFeeTransaction.where("id not in(?)", previously_processed_raw_pending_bank_fee_transactions_ids)
          end
        end

        def previously_processed_raw_pending_bank_fee_transactions_ids
          @previously_processed_raw_pending_bank_fee_transactions_ids ||= ::CanonicalPendingTransaction.bank_fee.pluck(:raw_pending_bank_fee_transaction_id)
        end

      end
    end
  end
end
