# frozen_string_literal: true

class Export
  module Format
    # A plain-text journal in the format read by ledger-cli, hledger and friends.
    class Journal < Base
      def name = "Ledger"
      def mime_type = "text/ledger"
      def extension = "ledger"

      def content(rows)
        journal = ::LedgerJournal::Journal.new

        rows.each do |row|
          journal.transactions << (row.amount_cents <= 0 ? expense(row) : income(row))
        end

        journal.to_s
      end

      private

      def expense(row)
        metadata = {}

        category = if row.merchant.nil?
                     "Transfer"
                   elsif public_only || row.merchant["category"].blank?
                     # Transparency viewers get the shape of the charge without
                     # naming the merchant it was made at.
                     "CardCharge"
                   else
                     metadata[:merchant] = row.merchant
                     metadata[:comments] = row.comments
                     row.merchant["category"].humanize.titleize.delete(" ")
                   end

        ::LedgerJournal::Transaction.new(
          date: row.date,
          payee: row.memo,
          metadata:,
          postings: [posting(account: "Expenses:#{category}", row:)]
        )
      end

      def income(row)
        ::LedgerJournal::Transaction.new(
          date: row.date,
          payee: row.memo,
          postings: [posting(account: "Income:#{row.income_type}", row:)]
        )
      end

      def posting(account:, row:)
        ::LedgerJournal::Posting.new(
          account:,
          currency: "USD",
          amount: BigDecimal(visible_amount_cents(row), 2) / 100
        )
      end

    end
  end

end
