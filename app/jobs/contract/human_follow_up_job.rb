# frozen_string_literal: true

class Contract
  # Nudges HCB's party when an agreement they're the point of contact for is
  # still unsigned. Unlike Contract::Party::ReminderJob this doesn't care
  # whether HCB is the one holding things up (or maybe they forgot to sign...).
  class HumanFollowUpJob < ApplicationJob
    queue_as :low
    discard_on ActiveJob::DeserializationError

    def perform(contract)
      return unless contract.sent?

      party = contract.party(:hcb)
      return if party.nil?

      Contract::PartyMailer.with(party:).human_follow_up.deliver_later
    end

  end

end
