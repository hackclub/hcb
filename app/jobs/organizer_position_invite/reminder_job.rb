# frozen_string_literal: true

class OrganizerPositionInvite
  class ReminderJob < ApplicationJob
    queue_as :low
    # Soft-deleted invites can't be deserialized; there's nothing to remind about
    discard_on ActiveJob::DeserializationError

    def perform(invite)
      return if invite.accepted? || invite.rejected? || invite.cancelled?
      # Signees are reminded to sign the contract first (see Contract::Party::ReminderJob)
      return if invite.pending_signature?
      # Initial demo-mode invites tell the applicant we're reviewing their application, not to accept anything
      return if invite.initial? && invite.event.demo_mode?

      OrganizerPositionInvitesMailer.with(invite:).reminder.deliver_later
    end

  end

end
