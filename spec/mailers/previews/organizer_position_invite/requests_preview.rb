# frozen_string_literal: true

class OrganizerPositionInvite
  class RequestsPreview < ActionMailer::Preview
    def created
      OrganizerPositionInvite::RequestsMailer.with(request: OrganizerPositionInvite::Request.pending.last).created
    end

    def denied
      OrganizerPositionInvite::RequestsMailer.with(request: OrganizerPositionInvite::Request.denied.last).denied
    end

  end

end
