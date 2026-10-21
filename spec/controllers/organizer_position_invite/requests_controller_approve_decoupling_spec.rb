# frozen_string_literal: true

require "rails_helper"

# Hybrid approval flow: managers can approve a request regardless of
# requester verification status, but only verified requesters are
# auto-accepted into the org. Unverified requesters get an OPI delivered
# (via OPI#after_create_commit :deliver) and must verify + accept it
# themselves — at which point the OPI#accept verification guard, the
# OrganizerPosition validation, and the canonical OPI accept controller
# converge to enforce the "no OP without verification" invariant.
RSpec.describe OrganizerPositionInvite::RequestsController, type: :controller do
  include SessionSupport

  describe "POST #approve" do
    let(:event) { create(:event) }
    let(:manager) do
      m = create(:user, verified: true)
      create(:organizer_position, user: m, event:, role: :manager)
      m
    end

    def build_request_for(requester:)
      link = event.organizer_position_invite_links.create!(creator: requester, expires_in: 0)
      OrganizerPositionInvite::Request.create!(requester:, link:)
    end

    context "when the requester is verified" do
      let(:requester) do
        r = create(:user, verified: true, email: "verified-#{SecureRandom.hex(2)}@example.invalid")
        r.affiliations.create!(name: "first", league: "frc", team_number: "1234")
        r
      end

      before { event.affiliations.create!(name: "first", league: "frc", team_number: "1234") }

      it "approves the request and auto-accepts the OPI (existing behavior)" do
        request_record = build_request_for(requester:)
        create_session(manager, verified: true)

        post :approve, params: { id: request_record.hashid, role: :member }

        expect(request_record.reload.aasm_state).to eq("approved")
        invite = OrganizerPositionInvite.where(event:, user: requester).last
        expect(invite&.accepted_at).to be_present, "Verified requesters should auto-accept; OPI was left pending."
        expect(OrganizerPosition.where(user: requester, event:)).to be_present
      end

      it "creates the printer raffle entry" do
        request_record = build_request_for(requester:)
        create_session(manager, verified: true)

        expect {
          post :approve, params: { id: request_record.hashid, role: :member }
        }.to change { Raffle.where(user: requester, program: "first-worlds-2026-printer").count }.by(1)
      end
    end

    context "when the requester is unverified" do
      let(:requester) do
        r = create(:user, verified: false, email: "unverified-#{SecureRandom.hex(2)}@example.invalid")
        r.affiliations.create!(name: "first", league: "frc", team_number: "1234")
        r
      end

      before { event.affiliations.create!(name: "first", league: "frc", team_number: "1234") }

      it "approves the request, creates an OPI, but does NOT auto-accept it" do
        request_record = build_request_for(requester:)
        create_session(manager, verified: true)

        post :approve, params: { id: request_record.hashid, role: :member }

        expect(request_record.reload.aasm_state).to eq("approved")
        invite = OrganizerPositionInvite.where(event:, user: requester).last
        expect(invite).to be_present
        expect(invite.accepted_at).to be_nil,
                                      "OPI must stay pending so the unverified requester can verify + accept on their own. " \
                                      "Auto-accepting here would short-circuit the verification gate."
        expect(OrganizerPosition.where(user: requester, event:)).to be_empty
      end

      it "still creates the printer raffle entry on approval" do
        request_record = build_request_for(requester:)
        create_session(manager, verified: true)

        expect {
          post :approve, params: { id: request_record.hashid, role: :member }
        }.to change { Raffle.where(user: requester, program: "first-worlds-2026-printer").count }.by(1)
      end
    end
  end
end
