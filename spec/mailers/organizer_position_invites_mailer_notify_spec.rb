# frozen_string_literal: true

require "rails_helper"

# The OPI notify email is reused for the request-approval flow, where the OPI
# may already be auto-accepted (verified requester) or still pending
# (unverified requester awaiting email verification). The body must adapt:
# verified flow has nothing left to accept, unverified flow needs to land on
# the OPI accept page.
RSpec.describe OrganizerPositionInvitesMailer, type: :mailer do
  describe "#notify for a request-approval invite" do
    let(:event) { create(:event) }
    let(:requester) { create(:user, verified: true, email: "requester-#{SecureRandom.hex(2)}@example.invalid") }

    def build_invite(accepted:)
      link = event.organizer_position_invite_links.create!(creator: requester, expires_in: 0)
      request_record = OrganizerPositionInvite::Request.create!(requester:, link:)
      invite = create(:organizer_position_invite, event:, user: requester, sender: create(:user, verified: true))
      invite.update!(organizer_position_invite_request: request_record)
      invite.accept if accepted
      invite.reload
    end

    it "links to the OPI accept page when the invite is still pending (unverified flow)" do
      pending_invite = build_invite(accepted: false)

      mail = described_class.with(invite: pending_invite).notify
      body = mail.body.encoded

      expect(body).to include(organizer_position_invite_url(pending_invite))
      expect(body).to match(/accept the invite/i)
    end

    it "links to the event itself when the invite was already auto-accepted (verified flow)" do
      accepted_invite = build_invite(accepted: true)

      mail = described_class.with(invite: accepted_invite).notify
      body = mail.body.encoded

      expect(body).to include(event_url(accepted_invite.event))
      expect(body).not_to match(/accept the invite/i),
                          "Verified requester's invite is already accepted by the time this email renders. " \
                          "Telling them to 'accept the invite' is misleading."
    end
  end
end
