# frozen_string_literal: true

module PayoutService
  module Invoice
    class Create
      def initialize(invoice_id:)
        @invoice_id = invoice_id
      end

      def run
        return nil unless charge # only continue if a charge exists (invoice might have been paid via check)
        return nil unless funds_available?
        return nil if invoice.payout_id.present?

        ActiveRecord::Base.transaction do
          payout.save!
          fee_reimbursement.save!
          invoice.update_column(:payout_id, payout.id)
          invoice.update_column(:fee_reimbursement_id, fee_reimbursement.id)

          payout
        end
      end

      private

      def payout
        @payout ||= ::InvoicePayout.new(invoice:, amount: invoice.payout_creation_balance_net + invoice.payout_creation_balance_stripe_fee)
      end

      def fee_reimbursement
        @fee_reimbursement ||= FeeReimbursement.new(invoice:)
      end

      def invoice
        @invoice ||= ::Invoice.find(@invoice_id)
      end

      def remote_invoice
        @remote_invoice ||= ::Partners::Stripe::Invoices::Show.new(id: invoice.stripe_invoice_id).run
      end

      def charge
        @charge ||= remote_invoice.charge
      end

      def funds_available?
        Time.current.to_i > remote_invoice.charge.balance_transaction.available_on
      end

    end
  end
end
