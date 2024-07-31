# frozen_string_literal: true

require "ledgerjournal"

module ExportService
  class Ledger
    BATCH_SIZE = 1000

    def initialize(event_id:, public_only: false)
      @event_id = event_id
      @public_only = public_only
    end

    def run
      journal = ::Ledger::Journal.new
      event.canonical_transactions.order("date desc").each do |ct|
        clean_amount = @public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents

        if ct.amount_cents <= 0
          hcb_code = ct.local_hcb_code
          merchant = ct.raw_stripe_transaction ? ct.raw_stripe_transaction.stripe_transaction["merchant_data"] : nil
          category = "Transfer"
          metadata = {}
          if merchant && !@public_only
            category = merchant["category"].humanize.titleize.delete(" ")
            metadata[:merchant] = merchant
            metadata[:comments] = ct.local_hcb_code.comments.not_admin_only.pluck(:content) unless @public_only && ct.local_hcb_code.comments.count.zero?
          elsif merchant
            category = "CardCharge"
          end
          journal.transactions << ::Ledger::Transaction.new(
            date: ct.date,
            payee: ct.local_hcb_code.memo,
            metadata:,
            postings: [
              ::Ledger::Posting.new(account: "Expenses:#{category}", currency: "USD", amount: BigDecimal(clean_amount, 2) / 100)
            ]
          )
        else
          income_type = "Transfer"
          hcb_code = ct.local_hcb_code
          if hcb_code.donation?
            income_type = "Donation"
          elsif hcb_code.invoice?
            income_type = "Invoice"
          end
          journal.transactions << ::Ledger::Transaction.new(
            date: ct.date,
            payee: ct.local_hcb_code.memo,
            postings: [
              ::Ledger::Posting.new(account: "Income:#{income_type}", currency: "USD", amount: BigDecimal(clean_amount, 2) / 100)
            ]
          )
        end
      end
      return journal.to_s
    end

    private

    def event
      @event ||= Event.find(@event_id)
    end

  end
end
