# frozen_string_literal: true

module TransactionEngine
  module SyntaxSugarService
    module Shared
      OUTGOING_CHECK_MEMO_PART = "CHECK TO ACCOUNT REDACTED"
      OUTGOING_ACH_MEMO_PART = "BUSBILLPAY" # possibly not guaranteed from SVB bank
      INCOMING_INVOICE_MEMO_PART1 = "HACKC PAYOUT"
      INCOMING_INVOICE_MEMO_PART2 = "HACK CLUB BANK PAYOUT"
      FEE_REFUND_MEMO_PART1 = "FEE REFUND"
      FEE_REFUND_MEMO_PART2 = "FROM ACCOUNT"
      DONATION_MEMO_PART1 = "HACKC DONATE"
      DONATION_MEMO_PART2 = "HACK CLUB BANK DONATE"
      DISBURSEMENT_MEMO_PART1 = "HCB DISBURSE"
      CLEARING_CHECK_MEMO_PART1 = "WITHDRAWAL - INCLEARING CHECK #"
      CLEARING_CHECK_MEMO_PART2 = "WITHDRAWAL - ON-US DEPOSITED ITE #"
      DDA_CHECK_MEMO_PART1 = "FROM DDA#80007609524 ON"
      DDA_CHECK_MEMO_PART2 = "AT"
      OUTGOING_BANK_FEE_MEMO = "HACK CLUB BANK FEE"

      private

      def amount_cents
        @canonical_transaction.amount_cents
      end

      def memo
        @memo ||= @canonical_transaction.memo.to_s
      end

      def memo_upcase
        @memo_upcase ||= memo.upcase
      end

      def outgoing_bank_fee?
        memo_upcase.include?(OUTGOING_BANK_FEE_MEMO)
      end

      def outgoing_check?
        memo_upcase.include?(OUTGOING_CHECK_MEMO_PART)
      end

      def clearing_check?
        memo_upcase.include?(CLEARING_CHECK_MEMO_PART1) || memo_upcase.include?(CLEARING_CHECK_MEMO_PART2)
      end

      def dda_check?
        memo_upcase.include?(DDA_CHECK_MEMO_PART1)
      end

      def likely_outgoing_check_number
        memo_upcase.gsub(OUTGOING_CHECK_MEMO_PART, "").strip
      end

      def likely_clearing_check_number
        memo_upcase.gsub(CLEARING_CHECK_MEMO_PART1, "").gsub(CLEARING_CHECK_MEMO_PART2, "").strip
      end

      def increase_check?
        @canonical_transaction.raw_increase_transaction&.increase_transaction&.dig("source", "category").in?(["check_transfer_intention", "check_transfer_deposit"]) ||
          @canonical_transaction.raw_column_transaction&.column_transaction&.dig("transaction_type")&.start_with?("check.incoming_debit")
      end

      def check_deposit?
        @canonical_transaction.raw_increase_transaction&.increase_transaction&.dig("source", "category") == "check_deposit_acceptance"
      end

      def column_check_deposit?
        @canonical_transaction.column_transaction_type&.start_with?("check.outgoing_debit")
      end

      def outgoing_ach?
        memo_upcase.include?(OUTGOING_ACH_MEMO_PART)
      end

      def increase_ach?
        @canonical_transaction.raw_increase_transaction&.increase_transaction&.dig("source", "category") == "ach_transfer_intention"
      end

      def column_ach?
        @canonical_transaction.column_transaction_type&.start_with?("ach.outgoing_transfer")
      end

      def column_realtime_transfer?
        @canonical_transaction.column_transaction_type&.start_with?("realtime.outgoing_transfer")
      end

      def column_wire?
        @canonical_transaction.column_transaction_type&.start_with?("swift.outgoing_transfer")
      end

      def likely_outgoing_ach_name
        memo_upcase.split(OUTGOING_ACH_MEMO_PART)[0].strip
      end

      def incoming_invoice?
        memo_upcase.include?(INCOMING_INVOICE_MEMO_PART1) || memo_upcase.include?(INCOMING_INVOICE_MEMO_PART2)
      end

      def likely_incoming_invoice_short_name
        memo_upcase.gsub(INCOMING_INVOICE_MEMO_PART1, "").gsub(INCOMING_INVOICE_MEMO_PART2, "").split(" ")[0]
      end

      def likely_invoice_for_fee_refund_hex_random_id
        memo_upcase.gsub(FEE_REFUND_MEMO_PART1, "").gsub(FEE_REFUND_MEMO_PART2, "").split(" ")[0]
      end

      def fee_refund?
        memo_upcase.include?(FEE_REFUND_MEMO_PART1) && memo_upcase.include?(FEE_REFUND_MEMO_PART2)
      end

      def donation?
        memo_upcase.include?(DONATION_MEMO_PART1) || memo_upcase.include?(DONATION_MEMO_PART2)
      end

      def likely_donation_short_name
        memo_upcase.gsub(DONATION_MEMO_PART1, "").gsub(DONATION_MEMO_PART2, "").split(" ")[0]
      end

      def likely_donation_for_fee_refund_hex_random_id
        memo_upcase.gsub(FEE_REFUND_MEMO_PART1, "").gsub(FEE_REFUND_MEMO_PART2, "").split(" ")[0]
      end

      def disbursement?
        memo_upcase.include?(DISBURSEMENT_MEMO_PART1)
      end

      def likely_disbursement_id
        memo_upcase.gsub(DISBURSEMENT_MEMO_PART1, "").split(" ")[0]
      end
    end
  end
end
