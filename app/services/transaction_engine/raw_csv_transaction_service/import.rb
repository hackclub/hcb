# frozen_string_literal: true

require "csv"
require "open-uri"

module TransactionEngine
  module RawCsvTransactionService
    class Import
      def run
        s = Set.new

        csvs.each do |csv|
          CSV.read(csv, headers: true).each do |row|
            next unless row.present? # skip empty rows

            raise ArgumentError, "csv_transaction_id #{row["csv_transaction_id"]} must be unique in the file" if s.include?(row["csv_transaction_id"])

            s.add(row["csv_transaction_id"])

            raise_any_argument_errors!(row:)

            ::RawCsvTransaction.find_or_initialize_by(csv_transaction_id: row["csv_transaction_id"]).tap do |rvt|
              rvt.unique_bank_identifier = row["unique_bank_identifier"]
              rvt.amount_cents = row["amount_cents"]
              rvt.date_posted = row["date"]
              rvt.memo = row["memo"]
              rvt.raw_data = row
            end.save!
          end
        end
      end

      private

      def raise_any_argument_errors!(row:)
        csv_transaction_id = row["csv_transaction_id"]

        raise ArgumentError, "unique_bank_identifier is required for row #{csv_transaction_id}" unless row["unique_bank_identifier"]
        raise ArgumentError, "amount_cents is required for row #{csv_transaction_id}" unless row["amount_cents"]
        raise ArgumentError, "date is required for row #{csv_transaction_id}" unless row["date"]
        raise ArgumentError, "memo is required for row #{csv_transaction_id}" unless row["memo"]
      end

      def csvs
        []
      end

      def csvs_path
        Rails.root.join("app/services/transaction_engine/csvs").to_s
      end

    end
  end
end
