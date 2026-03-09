# frozen_string_literal: true

class Contract
  class Party
    class ReminderJob < ApplicationJob
      queue_as :low

      def perform(party)
        return unless party.pending? && party.contract.sent?

        # If they're scheduled for an onboarding call, we shouldn't remind them
        return if party.contract.contractable.is_a?(Event::Application) && ["Interview Scheduled", "Invited to Interview"].include?(party.contract.contractable.airtable_record["Status"])

        Contract::PartyMailer.with(party:).reminder.deliver_later
      end

    end

  end

end
