# frozen_string_literal: true

class OrganizerPositionInvitesMailerPreview < ActionMailer::Preview
  def notify
    @invite = OrganizerPositionInvite.last
    OrganizerPositionInvitesMailer.with(invite: @invite).notify
  end

  def reminder
    @invite = OrganizerPositionInvite.pending.last
    OrganizerPositionInvitesMailer.with(invite: @invite).reminder
  end

  def accepted
    @invite = OrganizerPositionInvite.last
    OrganizerPositionInvitesMailer.with(invite: @invite).accepted
  end

end
