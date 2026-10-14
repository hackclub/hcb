# frozen_string_literal: true

class Subscription
  # Recomputes receipt requirements and card-locking deadlines for charges that
  # were unlinked from a subscription (it was deleted as "Not a subscription").
  # A charge that needs a receipt again gets a fresh deadline no earlier than
  # 72 hours from now, so un-marking can never lock a card instantly.
  class ResyncChargesJob < ApplicationJob
    queue_as :default

    def perform(hcb_code_ids:)
      HcbCode.where(id: hcb_code_ids).find_each do |hcb_code|
        # Re-requiring a receipt can never unlock a card, so skip the unlock job.
        hcb_code.refresh_receipt_state!(enqueue_unlock: false)
      end
    end

  end

end
