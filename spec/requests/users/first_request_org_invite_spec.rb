# frozen_string_literal: true

require "rails_helper"

# POST /first/request_org_invite — invoked from the "Request to join" card
# rendered to a user who:
#   - has a FIRST affiliation,
#   - is not yet a member of any HCB event matching that affiliation,
#   - matches an existing HCB Event by FIRST league + team_number.
#
# The controller derives the target Event from the user's affiliation
# server-side; nothing about which event is targeted is taken from params.
# Approval of the resulting OrganizerPositionInvite::Request feeds the user
# into the FIRST Worlds 3D-printer raffle (the join's marketing payoff).
#
# Uses controller-spec style for parity with the other authenticated
# Users::FirstController coverage (see SessionSupport).
RSpec.describe Users::FirstController, type: :controller do
  include SessionSupport

  let(:user) { create(:user, verified: true) }

  def give_user_first_affiliation(league: "frc", team_number: "1234")
    user.affiliations.create!(name: "first", league:, team_number:)
  end

  def event_with_first_affiliation(league: "frc", team_number: "1234")
    event = create(:event)
    event.affiliations.create!(name: "first", league:, team_number:)
    event
  end

  describe "POST #request_org_invite" do
    it "creates a pending OrganizerPositionInvite::Request for the matching event" do
      give_user_first_affiliation
      event = event_with_first_affiliation
      create_session(user, verified: true)

      expect {
        post(:request_org_invite)
      }.to change { OrganizerPositionInvite::Request.where(requester: user).count }.by(1)

      request_record = OrganizerPositionInvite::Request.where(requester: user).last
      expect(request_record.aasm_state).to eq("pending")
      expect(request_record.link.event).to eq(event)
    end

    it "creates an OrganizerPositionInvite::Link that is expired immediately" do
      give_user_first_affiliation
      event_with_first_affiliation
      create_session(user, verified: true)

      post(:request_org_invite)

      link = OrganizerPositionInvite::Request.where(requester: user).last.link
      expect(link.active?).to eq(false),
                              "Spec requires the helper Link to be expired immediately so it can't be reused. " \
                              "It is currently active."
      expect(link.creator).to eq(user)
    end

    it "redirects back to /first with a success flash on the happy path" do
      give_user_first_affiliation
      event_with_first_affiliation
      create_session(user, verified: true)

      post(:request_org_invite)

      expect(response).to redirect_to(first_index_path)
      expect(flash[:success]).to be_present
    end

    it "rejects with a redirect when the user has no FIRST affiliation" do
      event_with_first_affiliation
      create_session(user, verified: true)

      expect {
        post(:request_org_invite)
      }.not_to(change { OrganizerPositionInvite::Request.count })

      expect(response).to redirect_to(first_index_path)
      expect(flash[:error]).to be_present
    end

    it "rejects when no matching event exists for the user's affiliation" do
      give_user_first_affiliation(league: "frc", team_number: "1234")
      # Different team — no match.
      event_with_first_affiliation(league: "frc", team_number: "9999")
      create_session(user, verified: true)

      expect {
        post(:request_org_invite)
      }.not_to(change { OrganizerPositionInvite::Request.count })

      expect(response).to redirect_to(first_index_path)
      expect(flash[:error]).to be_present
    end

    it "rejects when the user is already an organizer of the matching event" do
      give_user_first_affiliation
      event = event_with_first_affiliation
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      expect {
        post(:request_org_invite)
      }.not_to(change { OrganizerPositionInvite::Request.count })

      expect(response).to redirect_to(first_index_path)
    end

    it "rejects when the user already has a pending request for the matching event" do
      give_user_first_affiliation
      event_with_first_affiliation
      create_session(user, verified: true)

      post(:request_org_invite)
      expect(OrganizerPositionInvite::Request.where(requester: user).count).to eq(1)

      expect {
        post(:request_org_invite)
      }.not_to(change { OrganizerPositionInvite::Request.where(requester: user).count })

      expect(response).to redirect_to(first_index_path)
    end

    it "ignores params and never creates a request for an arbitrary event_id" do
      # Server-derived target prevents a logged-in user with no matching
      # affiliation from POSTing the endpoint with a target event_id and
      # generating a Request for an unrelated event.
      give_user_first_affiliation(league: "frc", team_number: "1234")
      attacker_target = event_with_first_affiliation(league: "frc", team_number: "9999")
      create_session(user, verified: true)

      post(:request_org_invite, params: { event_id: attacker_target.id })

      expect(OrganizerPositionInvite::Request.where(requester: user)).to be_empty
    end

    it "does not create a request when no user is signed in" do
      event_with_first_affiliation

      expect {
        post(:request_org_invite)
      }.not_to(change { OrganizerPositionInvite::Request.count })
    end
  end
end
