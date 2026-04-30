# frozen_string_literal: true

require "rails_helper"

# When a manager approves an OrganizerPositionInvite::Request whose requester
# shares a FIRST affiliation with the event, the requester is auto-enrolled in
# the FIRST Worlds 3D-printer raffle. The previous implementation gated the
# raffle on the event having ANY FIRST affiliation, regardless of whether it
# matched the requester's team — meaning a hand-approved request from an
# unrelated user could grant a printer raffle entry. This spec pins the
# affiliation-match requirement.
RSpec.describe OrganizerPositionInvite::Request, type: :model do
  describe "#approve! after-callback raffle enrollment" do
    let(:requester) { create(:user, verified: true) }
    let(:event) { create(:event) }

    def build_request_for(event:, requester:)
      link = event.organizer_position_invite_links.create!(
        creator: requester,
        expires_in: 0,
      )
      described_class.create!(requester:, link:)
    end

    it "enrolls the requester in the printer raffle when the event affiliation matches the requester's" do
      requester.affiliations.create!(name: "first", league: "frc", team_number: "1234")
      event.affiliations.create!(name: "first", league: "frc", team_number: "1234")

      request_record = build_request_for(event:, requester:)

      expect {
        request_record.approve!
      }.to change {
        Raffle.where(user: requester, program: "first-worlds-2026-printer").count
      }.by(1)
    end

    it "does not enroll the requester when the event has no FIRST affiliation match for them" do
      requester.affiliations.create!(name: "first", league: "frc", team_number: "1234")
      # Event has a FIRST affiliation but for a different team.
      event.affiliations.create!(name: "first", league: "frc", team_number: "9999")

      request_record = build_request_for(event:, requester:)

      expect {
        request_record.approve!
      }.not_to(change {
        Raffle.where(user: requester, program: "first-worlds-2026-printer").count
      })
    end

    it "does not enroll the requester when neither party has a FIRST affiliation" do
      request_record = build_request_for(event:, requester:)

      expect {
        request_record.approve!
      }.not_to(change { Raffle.where(program: "first-worlds-2026-printer").count })
    end

    it "is idempotent — re-approving doesn't create a duplicate raffle entry" do
      requester.affiliations.create!(name: "first", league: "frc", team_number: "1234")
      event.affiliations.create!(name: "first", league: "frc", team_number: "1234")

      request_record = build_request_for(event:, requester:)
      request_record.approve!

      # Even if the after-callback fires twice for some reason, find_or_create_by!
      # must keep the raffle entry count at 1.
      Raffle.find_or_create_by!(user: requester, program: "first-worlds-2026-printer")

      expect(Raffle.where(user: requester, program: "first-worlds-2026-printer").count).to eq(1)
    end
  end
end
