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

        topup = StripeTopup.create(
          amount_cents:,
          statement_descriptor: "FEE REIMBURSE",
          description: "Fee reimbursement ##{fee_reimbursement.id}",
          metadata: {
            fee_reimbursement_id: fee_reimbursement.id,
          }
        )

        fee_reimbursement.update!(stripe_topup_id: topup.id, processed_at: Time.now)
      end
    end

  end
end
