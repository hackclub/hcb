# frozen_string_literal: true

class HcbCode
  module Memo
    extend ActiveSupport::Concern

    included do
      def memo(event: nil)
        return custom_memo if custom_memo.present?

        return card_grant_memo if card_grant?
        return incoming_disbursement_memo if incoming_disbursement?
        return outgoing_disbursement_memo if outgoing_disbursement?
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
        return wire_memo if wire?
        return wise_transfer_memo if wise_transfer?
        return stripe_service_fee_memo if stripe_service_fee?

        ct.try(:smart_memo) || pt.try(:smart_memo) || ""
      end

      def custom_memo
        ct.try(:custom_memo) || pt.try(:custom_memo)
      end

      def card_grant_memo
        "Grant to #{outgoing_disbursement.card_grant.user.name}".strip
      end

      def incoming_disbursement_memo
        return incoming_disbursement.special_appearance_memo if incoming_disbursement.special_appearance_memo

        "Transfer from #{incoming_disbursement.source_event.name}".strip
      end

      def outgoing_disbursement_memo
        return outgoing_disbursement.special_appearance_memo if outgoing_disbursement.special_appearance_memo

        "Transfer to #{outgoing_disbursement.destination_event.name}".strip
      end

      def invoice_memo
        "Invoice to #{invoice.smart_memo}".strip
      end

      def donation_memo
        "Donation from #{donation.smart_memo}#{donation.refunded? ? " (refunded)" : ""}".strip
      end

      def bank_fee_memo
        if bank_fee.amount_cents.negative? && bank_fee.fee_revenue.present?
          return "Fiscal sponsorship fee for #{bank_fee.fee_revenue.start.strftime("%-m/%-d")} to #{bank_fee.fee_revenue.end.strftime("%-m/%-d")}"
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
        "Fee revenue for #{fee_revenue.start.strftime("%-m/%-d")} to #{fee_revenue.end.strftime("%-m/%-d")}"
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

      def stripe_service_fee_memo
        stripe_service_fee.stripe_description
      end

      def wire_memo
        "Wire to #{wire.recipient_name}"
      end

      def wise_transfer_memo
        "Wise transfer to #{wise_transfer.recipient_name}"
      end

    end
  end

end
