# frozen_string_literal: true

module TransactionEngine
  module HashedTransactionService
    module RawPlaidTransaction
      class Import
        include ::TransactionEngine::Shared

        def initialize(start_date: nil)
          @start_date = start_date || last_1_month
        end

        def run
          ::RawPlaidTransaction.where("date_posted >= ?", @start_date).find_each(batch_size: 100) do |pt|
            begin
              next if pt.amount_cents == 0

              ph = primary_hash(pt)

              # Option 1, instead of finding by primary hash here, I could find by raw_plaid_transaction id ?
              ::HashedTransaction.find_or_initialize_by(raw_plaid_transaction_id: pt.id).tap do |ht|
                ht.primary_hash = ph[0]
                ht.primary_hash_input = ph[1]
              end.save!
            rescue ArgumentError => e
              puts "RawPlaidTransaction #{pt.id}: #{e}"

              raise e
            end
          end
        end

        private

        def primary_hash(pt)
          ::TransactionEngine::HashedTransactionService::PrimaryHash.new(
            unique_bank_identifier: pt.unique_bank_identifier,
            date: pt.date_posted.strftime("%Y-%m-%d"),
            amount_cents: pt.amount_cents,
            memo: pt.memo.upcase
          ).run
        end

      end
    end
  end
end
