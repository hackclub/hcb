# frozen_string_literal: true

module PendingTransactionEngine
  module RawPendingInvoiceTransactionService
    module Invoice
      class ImportSingle
        def initialize(invoice:)
          @invoice = invoice
        end

        def run
          return if @invoice.manually_marked_as_paid? # Manually marked as paid invoices don't have pending transactions

          @invoice.sync_remote!

          rpit = ::RawPendingInvoiceTransaction.find_or_initialize_by(invoice_transaction_id: @invoice.id.to_s).tap do |t|
            t.amount_cents = @invoice.amount_paid
            t.date_posted = @invoice.paid_at
          end

          rpit.save!

          rpit
        end

      end
    end
  end
end
