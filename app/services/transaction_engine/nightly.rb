# frozen_string_literal: true

module TransactionEngine
  class Nightly
    include ::TransactionEngine::Shared

    def initialize(start_date: nil)
      @start_date = start_date || 1.week.ago
    end

    def run
      # (1) Import transactions
      safely { import_raw_plaid_transactions! }
      safely { import_raw_stripe_transactions! }
      safely { import_raw_csv_transactions! }
      safely { import_raw_column_transactions! }

      # (2) Hash transactions
      safely { hash_raw_plaid_transactions! }
      safely { hash_raw_stripe_transactions! }
      safely { hash_raw_csv_transactions! }

      # (3) Canonize transactions
      safely { canonize_hashed_transactions! }

      # (4) Fix plaid mistakes
      fix_plaid_mistakes!

      # (5) Fix memo mistakes
      safely { fix_memo_mistakes! }
    end

    private

    def import_raw_plaid_transactions!
      BankAccount.syncing_v2.pluck(:id).each do |bank_account_id|
        Rails.error.handle do
          puts "raw_plaid_transactions: #{bank_account_id}"

          ::TransactionEngine::RawPlaidTransactionService::Plaid::Import.new(bank_account_id:, start_date: @start_date).run
        end
      end
    end

    def import_raw_stripe_transactions!
      ::TransactionEngine::RawStripeTransactionService::Stripe::Import.new(start_date: @start_date).run
    end

    def import_raw_csv_transactions!
      ::TransactionEngine::RawCsvTransactionService::Import.new.run
    end

    def import_raw_column_transactions!
      transactions_by_report = ColumnService.transactions(from_date: @start_date)

      transactions_by_report.each do |report_id, transactions|
        transactions.each_with_index do |transaction, transaction_index|
          if transaction["effective_at"] == transaction["effective_at_utc"] && transaction["effective_at_utc"] < "2024-10-07T04:00:00Z"
            notice = "Skipping the import of the following transaction in #{report_id}"
            puts notice
            puts transaction
            Airbrake.notify(notice, transaction)
            next
          end

          # transactions that meet this condition would have been imported in a report using EST
          # they should be skipped when importing from a UTC report.
          # this is related to the transition from reporting in EST to UTC.
          #
          # explanation of each condition
          #
          # transaction["effective_at"] == transaction["effective_at_utc"]
          #
          # if this condition is true, this report was generated in UTC
          #
          # transaction["effective_at_utc"] < "2024-10-07T04:00:00Z"
          #
          # if this condition is true, it is from a time when we generated reports using EST

          raw_column_transaction = RawColumnTransaction.find_or_create_by(column_report_id: report_id, transaction_index:) do |rct|
            rct.amount_cents = transaction["available_amount"]
            rct.date_posted = transaction["effective_at"]
            rct.column_transaction = transaction
          end
        end
      end
    end

    def hash_raw_plaid_transactions!
      ::TransactionEngine::HashedTransactionService::RawPlaidTransaction::Import.new(start_date: @start_date).run
    end

    def hash_raw_stripe_transactions!
      ::TransactionEngine::HashedTransactionService::RawStripeTransaction::Import.new(start_date: @start_date).run
    end

    def hash_raw_csv_transactions!
      ::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
    end

    def canonize_hashed_transactions!
      ::TransactionEngine::CanonicalTransactionService::Import::All.new.run
    end

    def fix_plaid_mistakes!
      BankAccount.syncing_v2.pluck(:id).each do |bank_account_id|
        Rails.error.handle do
          ::TransactionEngine::FixMistakes::Plaid.new(bank_account_id:, start_date: @start_date.to_date.iso8601, end_date: nil).run
        end
      end
    end

    def fix_memo_mistakes!
      ::TransactionEngine::FixMistakes::Memos.new(start_date: @start_date).run
    end

  end
end
