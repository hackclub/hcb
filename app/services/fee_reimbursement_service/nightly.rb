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
            statement_descriptor: "HCB-#{fee_reimbursement_group.local_hcb_code.short_code}",
            description: "Fee reimbursement ##{fee_reimbursement.id}",
            metadata: {
              fee_reimbursement_id: fee_reimbursement.id,
            }
          )

          fee_reimbursement.update!(stripe_topup_id: topup.id, processed_at: Time.now, fee_reimbursement_group:)
        end
      end
    end

    private

    # Every top-up made this week shares the group's HCB code: its short code is
    # the statement descriptor, which is how each bank debit finds the group's
    # ledger item when it comes in.
    def fee_reimbursement_group
      @fee_reimbursement_group ||= FeeReimbursementGroup.find_or_create_by!(slug: Time.now.strftime(FeeReimbursementGroup::WEEK_FORMAT))
    end

  end
end
