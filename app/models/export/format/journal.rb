# frozen_string_literal: true

class Export
  module Format
    # A plain-text journal in the format read by ledger-cli, hledger and friends.
    class Journal < Base
      READS = %i[comments merchant].freeze

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
        # Transparency viewers get the shape of the charge without the merchant
        # it was made at. Organizers get the merchant whether or not Stripe
        # categorized it.
        metadata = public_only || row.merchant.nil? ? {} : { merchant: row.merchant, comments: row.comments }
        category = row.merchant.nil? ? "Transfer" : merchant_category(row.merchant)

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

      def merchant_category(merchant)
        return "CardCharge" if public_only || merchant["category"].blank?

        merchant["category"].humanize.titleize.delete(" ")
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
