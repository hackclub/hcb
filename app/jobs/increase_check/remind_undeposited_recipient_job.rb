# frozen_string_literal: true

class IncreaseCheck
  class RemindUndepositedRecipientJob < ApplicationJob
    queue_as :low
    def perform(check)
      # Has not changed state (e.g. deposited) since issued
      if check.column_issued?
        IncreaseCheckMailer.with(check:).remind_recipient.deliver_later
      end


    end

  end

end

module IncreaseCheckJob
  RemindUndepositedRecipient = IncreaseCheck::RemindUndepositedRecipientJob
end
