# frozen_string_literal: true

require "rails_helper"

# System invariant: an unverified user cannot hold an OrganizerPosition.
# An attacker can register an unverified User via /first/welcome (no email
# confirmation gate) and submit a request to join a real org. Without this
# rule, a manager who clicks "approve" creates an OrganizerPosition tied to
# an account whose email may not even belong to the requester. Enforced at
# three layers: the OP model itself (the single source of truth), and the
# two flows that create OPs (OrganizerPositionInvite#accept and
# OrganizerPositionInvite::Request#approve!).
RSpec.describe "Unverified users cannot have an OrganizerPosition" do
  describe "OrganizerPosition model" do
    it "rejects creation when the user is unverified" do
      user = create(:user, verified: false)
      event = create(:event)
      invite = create(:organizer_position_invite, event:, user:)
      op = OrganizerPosition.new(user:, event:, organizer_position_invite: invite, role: :manager)

      expect(op).not_to be_valid
      expect(op.errors[:user]).to be_present,
                                  "OrganizerPosition validation should block unverified users on create. " \
                                  "Got errors: #{op.errors.full_messages.inspect}"
    end

    it "allows creation when the user is verified" do
      user = create(:user, verified: true)
      event = create(:event)
      invite = create(:organizer_position_invite, event:, user:)
      op = OrganizerPosition.new(user:, event:, organizer_position_invite: invite, role: :manager)

      expect(op).to be_valid
    end

    it "does not invalidate existing OrganizerPositions if the user is somehow unverified later" do
      # The validation must be `on: :create` to avoid retroactively breaking
      # rows whose user.verified is later toggled (e.g., admin tooling). The
      # invariant is about who CAN BECOME an organizer, not about a property
      # an existing organizer must maintain.
      user = create(:user, verified: true)
      op = create(:organizer_position, user:, event: create(:event))
      user.update_columns(verified: false)
      op.reload

      expect(op).to be_valid
    end
  end

  describe "OrganizerPositionInvite#accept" do
    it "returns false and surfaces an error when the invitee is unverified" do
      user = create(:user, verified: false)
      event = create(:event)
      invite = create(:organizer_position_invite, event:, user:)

      expect(invite.accept).to eq(false)
      expect(invite.errors.full_messages.join(" ")).to match(/verif/i)
      expect(invite.reload.accepted_at).to be_nil
      expect(OrganizerPosition.where(user:, event:)).to be_empty
    end

    it "succeeds when the invitee is verified" do
      user = create(:user, verified: true)
      event = create(:event)
      invite = create(:organizer_position_invite, event:, user:)

      expect(invite.accept).to be_truthy
      expect(invite.reload.accepted_at).to be_present
    end
  end

  describe "OrganizerPositionInvite::Request#approve!" do
    # Approving the Request is decoupled from the requester's verification
    # status. The verification gate moves downstream to OPI#accept (and the OP
    # validation), so a manager can approve the Request and the requester then
    # has a normal "verify-then-accept" flow via the OPI email. This shape
    # also keeps the printer-raffle invariant simple: raffle entry follows
    # manager approval, not user verification.
    let(:event) { create(:event) }

    def build_request_for(user:)
      link = event.organizer_position_invite_links.create!(creator: user, expires_in: 0)
      OrganizerPositionInvite::Request.create!(requester: user, link:)
    end

    it "transitions to approved when the requester is unverified" do
      requester = create(:user, verified: false)
      request_record = build_request_for(user: requester)

      expect { request_record.approve! }.to change { request_record.reload.aasm_state }.from("pending").to("approved")
    end

    it "still creates the printer raffle entry on approval when the requester is unverified but affiliation matches" do
      requester = create(:user, verified: false)
      requester.affiliations.create!(name: "first", league: "frc", team_number: "1234")
      event.affiliations.create!(name: "first", league: "frc", team_number: "1234")
      request_record = build_request_for(user: requester)

      expect {
        request_record.approve!
      }.to change { Raffle.where(user: requester, program: "first-worlds-2026-printer").count }.by(1)
    end

    it "transitions normally when the requester is verified" do
      requester = create(:user, verified: true)
      request_record = build_request_for(user: requester)

      expect { request_record.approve! }.to change { request_record.reload.aasm_state }.from("pending").to("approved")
    end
  end

  describe "OrganizerPositionInvite::RequestsMailer#created exposes the requester's email" do
    it "includes the requester's email so managers can sanity-check identity before approving" do
      # Without the email, a manager only sees the requester's name. Names
      # are easy to spoof at /first/welcome; team-roster lookup keys off
      # email. Surfacing email lets a manager match the request to a known
      # roster entry before they hand out an OrganizerPosition.
      requester = create(:user, verified: false, email: "roster-check-#{SecureRandom.hex(2)}@example.invalid")
      event = create(:event)
      link = event.organizer_position_invite_links.create!(creator: requester, expires_in: 0)
      request_record = OrganizerPositionInvite::Request.create!(requester:, link:)

      mail = OrganizerPositionInvite::RequestsMailer.with(request: request_record).created
      body = mail.body.encoded

      expect(body).to include(requester.email),
                      "Mailer should print the requester's email so managers can verify identity before approval. " \
                      "Body did not contain #{requester.email.inspect}."
    end
  end
end
