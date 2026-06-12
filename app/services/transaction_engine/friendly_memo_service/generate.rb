# frozen_string_literal: true

module TransactionEngine
  module FriendlyMemoService
    class Generate
      def initialize(canonical_transaction:)
        @canonical_transaction = canonical_transaction
      end

      def run
        friendly_memo = handle_hack_club_bank_fee ||
                        handle_linked_object ||
                        handle_emburse_refund ||
                        handle_solely_from_memo

        return friendly_memo.to_s.upcase if friendly_memo

        nil
      end

      private

      def handle_hack_club_bank_fee
        return "FISCAL SPONSORSHIP" if hack_club_fee?
      end

      def handle_linked_object
        case linked_object.class.to_s
        when "Disbursement"
          "DISBURSEMENT #{linked_object.name.to_s.upcase}"
        when "Invoice"
          "INVOICE #{linked_object.sponsor.name.to_s.upcase}"
        when "Donation"
          "DONATION #{linked_object.name.to_s.upcase}"
        else
          nil
        end
      end

      def handle_emburse_refund
        return (raw_emburse_transaction.bank_account_description || raw_emburse_transaction.merchant_description).to_s.upcase.presence if amount_cents > 0 && raw_emburse_transaction.present?
      end

      def handle_solely_from_memo
        @handle_solely_from_memo ||= ::TransactionEngine::FriendlyMemoService::GenerateSolelyFromMemo.new(canonical_transaction: @canonical_transaction).run
      end

      def amount_cents
        @canonical_transaction.amount_cents
      end

      def linked_object
        @canonical_transaction.linked_object
      end

      def raw_emburse_transaction
        @canonical_transaction.raw_emburse_transaction
      end

      def hack_club_fee?
        @canonical_transaction.likely_hack_club_fee?
      end

    end
  end
end
