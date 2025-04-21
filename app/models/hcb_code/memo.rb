# frozen_string_literal: true

class HcbCode
  module Memo
    extend ActiveSupport::Concern

    included do
      def memo(event: nil)
        return custom_memo if custom_memo.present?

        return card_grant_memo if card_grant?
        return disbursement_memo(event:) if disbursement?
        return invoice_memo if invoice?
        return donation_memo if donation?
        return bank_fee_memo if bank_fee?
        return reimbursement_payout_holding_memo if reimbursement_payout_holding?
        return reimbursement_expense_payout_memo if reimbursement_expense_payout?
        return reimbursement_payout_transfer_memo if reimbursement_payout_transfer?
        # reimbursement related memos must come before ach_transfer / increase_check
        # as reimbursement_payout_transfers can also be ach_transfers or increase_checks
        return ach_transfer_memo if ach_transfer?
        return check_memo if check?
        return increase_check_memo if increase_check?
        return check_deposit_memo if check_deposit?
        return fee_revenue_memo if fee_revenue?
        return outgoing_fee_reimbursement_memo if outgoing_fee_reimbursement?
        return stripe_card_memo if stripe_card? && stripe_card_memo

        ct.try(:smart_memo) || pt.try(:smart_memo) || ""
      end

      def custom_memo
        ct.try(:custom_memo) || pt.try(:custom_memo)
      end

      def card_grant_memo
        "Grant to #{disbursement.card_grant.user.name}".strip
      end

      def disbursement_memo(event: nil)
        return disbursement.special_appearance_memo if disbursement.special_appearance_memo

        if event == disbursement.source_event
          "Transfer to #{disbursement.destination_event.name}".strip
        elsif event == disbursement.destination_event
          "Transfer from #{disbursement.source_event.name}".strip
        else
          "Transfer from #{disbursement.source_event.name} to #{disbursement.destination_event.name}".strip
        end

      end

      def invoice_memo
        "Invoice to #{invoice.smart_memo}".strip
      end

      def donation_memo
        "Donation from #{donation.smart_memo}#{donation.refunded? ? " (refunded)" : ""}".strip
      end

      def bank_fee_memo
        if bank_fee.amount_cents.negative? && bank_fee.fee_revenue.present?
          return "Fiscal sponsorship for #{bank_fee.fee_revenue.start.strftime("%-m/%-d")} to #{bank_fee.fee_revenue.end.strftime("%-m/%-d")}"
        elsif bank_fee.amount_cents.negative?
          return "Fiscal sponsorship"
        else
          return "Fiscal sponsorship fee credit"
        end
      end

      def ach_transfer_memo
        "ACH to #{ach_transfer.smart_memo}".strip
      end

      def check_memo
        "Check to #{check.smart_memo}".strip
      end

      def increase_check_memo
        "Check to #{increase_check.recipient_name}".strip
      end

      def check_deposit_memo
        "Check deposit"
      end

      def fee_revenue_memo
        "Fee revenue from #{fee_revenue.start.strftime("%b %e")} to #{fee_revenue.end.strftime("%b %e")}"
      end

      def outgoing_fee_reimbursement_memo
        "🗂️ Stripe fee reimbursements for week of #{ct.date.beginning_of_week.strftime("%-m/%-d")}"
      end

      def reimbursement_payout_holding_memo
        "Payout holding for reimbursement report #{reimbursement_payout_holding.report.hashid}"
      end

      def reimbursement_expense_payout_memo
        reimbursement_expense_payout.expense.memo
      end

      def reimbursement_payout_transfer_memo
        "Payout transfer for reimbursement report #{reimbursement_payout_transfer.reimbursement_payout_holding.report.hashid}"
      end

      def stripe_card_memo
        YellowPages::Merchant.lookup(network_id: stripe_merchant["network_id"]).name || stripe_merchant["name"]
      end

    end
  end

end
