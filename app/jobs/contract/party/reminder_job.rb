# frozen_string_literal: true

class Contract
  class Party
    class ReminderJob < ApplicationJob
      queue_as :low

      def perform(party)
        return unless party.pending? && party.contract.sent?

        Contract::PartyMailer.with(party:).reminder.deliver_later
      end

    end

  end

end
