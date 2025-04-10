# frozen_string_literal: true

module InvoiceService
  class Refund
    def initialize(invoice_id:, amount:)
      @invoice_id = invoice_id
      @amount = amount
    end

    def run
      raise ArgumentError, "the invoice must have settled" unless invoice.canonical_transactions.any?
      raise ArgumentError, "the invoice has already been refunded" if invoice.refunded?

      ActiveRecord::Base.transaction do

        # 1. Un-front all pending transaction associated with this invoice
        invoice.canonical_pending_transactions.update_all(fronted: false)

        # 2. Process remotely
        ::StripeService::Refund.create(charge: stripe_charge_id, amount: @amount)

        # 3. Create top-up on Stripe. Located in `StripeController#handle_charge_refunded`

        # 4. Mark the invoice as refunded

        invoice.mark_refunded!
      end
    end

    private

    def invoice
      @invoice ||= ::Invoice.find(@invoice_id)
    end

    def stripe_charge_id
      invoice.stripe_charge_id
    end

    def stripe_invoice_id
      invoice.stripe_invoice_id
    end

  end
end
