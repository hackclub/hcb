# frozen_string_literal: true

module CardLocking
  # Materializes a settled card charge's card-locking timing. Idempotent; enqueued
  # from both transaction engines' mapping hooks. Trust-based sliding is applied
  # later by the recurring sweep, so this uses the default (untrusted) deadline.
  class MaterializeChargeJob < ApplicationJob
    queue_as :low

    def perform(hcb_code_id:)
      hcb_code = HcbCode.find_by(id: hcb_code_id)
      return unless hcb_code

      hcb_code.materialize_card_locking!(now: Time.current)
    end

  end
end
