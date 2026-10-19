# frozen_string_literal: true

module TransactionEngine
  module FriendlyMemoService
    class GenerateSolelyFromMemo
      include ::TransactionEngine::SyntaxSugarService::Shared

      def initialize(canonical_transaction:)
        @canonical_transaction = canonical_transaction
      end

      def run
        if memo.present?

          return "CHECK ##{likely_outgoing_check_number}" if outgoing_check?

          return "ACH TRANSFER #{likely_outgoing_ach_name}" if outgoing_ach?

          return "FEE REFUND" if fee_refund?

          return "TRANSFER FROM ACCOUNT TO CARD BALANCE" if emburse_transfer_from_account_to_card_balance?

          return "TRANSFER FROM BANK ACCOUNT" if emburse_transfer_from_fiscal_sponsorship?

          return "DONATION" if donation?

          return "INVOICE #{likely_incoming_invoice_short_name}" if incoming_invoice?

          # @msw: temporary patch to fix
          # https://github.com/hackclub/hcb/issues/2670 in production. This
          # should have a permanent fix.
          memo.gsub(/(FROM|TO) ACCOUNT \d+$/, "")

        else

          return "TRANSFER FROM BANK ACCOUNT" if amount_cents > 0 # emburse transaction

          return "TRANSFER BACK TO BANK ACCOUNT" if amount_cents < 0 # emburse transaction

          nil
        end
      end

      private

      def emburse_transfer_from_account_to_card_balance?
        memo_upcase.include?("EMBURSE.COM EMBURSE.CO") || memo_upcase.include?("EMBURSE.COM TRANSFER")
      end

      def emburse_transfer_from_fiscal_sponsorship?
        memo_upcase.include?("TRANSFER FROM FISCAL SPONSORSHIP (NEW) - 7027") || memo_upcase.include?("TRANSFER FROM FS MAIN - 7027")
      end

    end
  end
end
