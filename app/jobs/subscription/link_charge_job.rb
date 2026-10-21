# frozen_string_literal: true

class Subscription
  class LinkChargeJob < ApplicationJob
    queue_as :low

    def perform(canonical_transaction)
      return unless canonical_transaction.amount_cents.negative?
      return unless canonical_transaction.transaction_source_type == RawStripeTransaction.name

      hcb_code = canonical_transaction.local_hcb_code
      Subscription::LinkCharge.new(hcb_code:).run if hcb_code
    end

  end

end
