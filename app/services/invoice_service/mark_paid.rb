# frozen_string_literal: true

module InvoiceService
  # This service handles marking open Invoices as "manually paid". This service
  # is used in scenarios where an invoice issued via Stripe was paid "out of
  # band" of Stripe. For example, via Bill.com, PayPal, or a paper check mailed
  # to our Santa Monica address.
  class MarkPaid
    def initialize(invoice_id:, reason:, user:, attachment: nil)
      @invoice_id = invoice_id
      @reason = reason
      @attachment = attachment
      @user = user
    end

    def run
      GovernanceService::Admin::Transfer::Approval.new(
        transfer: invoice,
        amount_cents: invoice.item_amount,
        user: @user,
      ).ensure_may_approve!

      raise ArgumentError, "reason is required" if @reason.blank?
      if invoice.remote_paid? && invoice.remote_charge
        raise ArgumentError, "can not manually mark an invoice as paid when it was already paid through Stripe"
      end

      ActiveRecord::Base.transaction do
        # If an invoice was already marked as paid on Stripe, then use the
        # paid_at time from Stripe.
        invoice.manually_marked_as_paid_at =
          if invoice.remote_paid?
            Time.at(remote_invoice.status_transitions.paid_at)
          else
            Time.now
          end

        invoice.manually_marked_as_paid_user = @user
        invoice.manually_marked_as_paid_reason = @reason
        invoice.manually_marked_as_paid_attachment = @attachment
        invoice.save!
        invoice.mark_paid! # aasm

        # `pay` returns the updated invoice rather than refreshing the memoized one
        @remote_invoice = remote_invoice.pay(paid_out_of_band: true) unless invoice.remote_paid?
      end

      invoice.set_fields_from_stripe_invoice(remote_invoice)
      invoice.save!
    end

    private

    def invoice
      @invoice ||= Invoice.find(@invoice_id)
    end

    def remote_invoice
      @remote_invoice ||= invoice.remote_invoice
    end

  end
end
