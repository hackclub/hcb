# frozen_string_literal: true

module PendingTransactionEngine
  module FriendlyMemoService
    class Generate
      def initialize(pending_canonical_transaction:)
        @pending_canonical_transaction = pending_canonical_transaction
      end

      def run
        return "CHECK ##{check_number}" if outgoing_check?
        return "INVOICE TO #{invoice_name}" if invoice?
        return "DONATION FROM #{donation_name}" if donation?

        memo
      end

      private

      def memo
        @memo ||= @pending_canonical_transaction.memo
      end

      def memo_upcase
        memo.upcase
      end

      def outgoing_check?
        @outgoing_check ||= raw_pending_outgoing_check_transaction.present?
      end

      def invoice?
        @invoice ||= raw_pending_invoice_transaction&.invoice.present?
      end

      def donation?
        @donation ||= raw_pending_donation_transaction&.donation.present?
      end

      def raw_pending_outgoing_check_transaction
        @raw_pending_outgoing_check_transaction ||= @pending_canonical_transaction.raw_pending_outgoing_check_transaction
      end

      def check_number
        raw_pending_outgoing_check_transaction.check_number
      end

      def raw_pending_invoice_transaction
        @raw_pending_invoice_transaction ||= @pending_canonical_transaction.raw_pending_invoice_transaction
      end

      def invoice_name
        raw_pending_invoice_transaction.invoice.sponsor.name.to_s.upcase
      end

      def raw_pending_donation_transaction
        @raw_pending_donation_transaction ||= @pending_canonical_transaction.raw_pending_donation_transaction
      end

      def donation_name
        raw_pending_donation_transaction.donation.smart_memo
      end

    end
  end
end
