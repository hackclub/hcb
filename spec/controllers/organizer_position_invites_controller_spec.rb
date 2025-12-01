# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPositionInvitesController do
  include SessionSupport
  render_views

  describe "#create" do
    it "creates an invitation" do
      user = create(:user)
      event = create(:event, organizers: [user])

      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          organizer_position_invite: {
            email: "orpheus@hackclub.com",
            role: "member",
            enable_controls: "true",
            initial_control_allowance_amount: "123.45",
          }
        }
      )

      expect(response).to redirect_to(event_team_path(event))
      expect(flash[:success]).to eq("Invite successfully sent to orpheus@hackclub.com")

      invite = event.organizer_position_invites.last
      expect(invite.sender).to eq(user)
      expect(invite.user.email).to eq("orpheus@hackclub.com")
      expect(invite.role).to eq("member")
      expect(invite.initial_control_allowance_amount_cents).to eq(123_45)
    end

    it "supports additional params for admins" do
      user = create(:user, :make_admin)
      event = create(:event, organizers: [user])

      # `Contract` makes external requests to Airtable and
      # Docuseal which we don't want to perform in this context.
      expect(ApplicationsTable).to(
        receive(:all)
          .with(filter: include(event.id.to_s))
          .and_return([])
          .twice
      )
      docuseal_request =
        stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(
          status: 201,
          body: [{ submission_id: "STUBBED" }].to_json,
          headers: { content_type: "application/json" }
        )

      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          organizer_position_invite: {
            email: "orpheus@hackclub.com",
            role: "owner",
            enable_controls: "false",
            cosigner_email: "cosigner@hackclub.com",
            include_videos: "true",
          }
        }
      )

      expect(docuseal_request).to(have_been_made.once)

      expect(response).to redirect_to(event_team_path(event))
      expect(flash[:success]).to eq("Invite successfully sent to orpheus@hackclub.com")

      invite = event.organizer_position_invites.last
      expect(invite.role).to eq("owner")

      contract = invite.contracts.sole
      expect(contract.cosigner_email).to eq("cosigner@hackclub.com")
      expect(contract.include_videos).to eq(true)
      expect(contract.external_service).to eq("docuseal")
      expect(contract.external_id).to eq("STUBBED")
    end
  end
end
