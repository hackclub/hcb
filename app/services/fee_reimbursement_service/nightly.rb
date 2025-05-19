# frozen_string_literal: true

# Prior to Monday 9th December. We processed fee reimbursements
# by making a book transfer to cover the difference between the payout
# from Stripe and the amount paid.

# Now, we payout the full amount from Stripe (incl. the fee) and then
# top up our Stripe balance to cover that fee.

# This service performs that top-up.

# We made this change to handle $1 payouts.

module FeeReimbursementService
  class Nightly
    def run
      FeeReimbursement.unprocessed.find_each(batch_size: 100) do |fee_reimbursement|
        raise ArgumentError, "must be an unprocessed fee reimbursement only" unless fee_reimbursement.unprocessed?

        amount_cents = fee_reimbursement.amount

        if amount_cents.zero?
          fee_reimbursement.update!(processed_at: Time.now)
        else
          topup = StripeTopup.create(
            amount_cents:,
            statement_descriptor: "HCB-#{local_hcb_code.short_code}",
            description: "Fee reimbursement ##{fee_reimbursement.id}",
            metadata: {
              fee_reimbursement_id: fee_reimbursement.id,
            }
          )

          fee_reimbursement.update!(stripe_topup_id: topup.id, processed_at: Time.now)
        end
      end
    end

    def hcb_code
      [
        ::TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
        ::TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
        Time.now.strftime("%G_%V")
      ].join(::TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
    end

    def local_hcb_code
      HcbCode.find_or_create_by(hcb_code:)
    end

  end
end
