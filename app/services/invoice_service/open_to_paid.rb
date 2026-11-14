# frozen_string_literal: true

module InvoiceService
  class OpenToPaid
    def initialize(invoice_id:)
      @invoice_id = invoice_id
    end

    def run
      return if invoice.paid_v2? # return if already marked paid
      return unless invoice.remote_paid? && invoice.remote_charge.present? # only process if invoice was paid and was paid with a remote charge. check paid invoices are handled differently

      ::ActiveRecord::Base.transaction do
        invoice.sync_remote!
        invoice.mark_paid!

        b_tnx = invoice.remote_charge.balance_transaction

        funds_available_at = Util.unixtime(b_tnx.available_on)
        create_payout_at = funds_available_at + 1.day

        invoice.payout_creation_queued_at = Time.current
        invoice.payout_creation_queued_for = create_payout_at
        invoice.payout_creation_balance_net = b_tnx.net - hidden_fee(invoice.remote_charge) # amount to pay out
        invoice.payout_creation_balance_stripe_fee = b_tnx.fee + hidden_fee(invoice.remote_charge)
        invoice.payout_creation_balance_available_at = funds_available_at

        invoice.save!
      end

      if invoice.event.users.any?
        InvoiceMailer.with(invoice:).notify_organizers_paid.deliver_later
      end
    end

    def hidden_fee(c)
      # stripe has hidden fees for ACH Credit TXs that don't show in the API at the moment:
      # https://support.stripe.com/questions/pricing-of-payment-methods-in-the-us
      if c.payment_method_details.type != "ach_credit_transfer"
        return 0
      end

      if c.amount < 1000 * 100
        return 700
      elsif c.amount < 100000 * 100
        return 1450
      else
        return 2450
      end
    end

    def invoice
      @invoice ||= Invoice.find(@invoice_id)
    end

  end
end
