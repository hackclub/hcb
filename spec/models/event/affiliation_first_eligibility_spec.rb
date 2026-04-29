# frozen_string_literal: true

require "rails_helper"

# Shared eligibility helpers used by Users::FirstController#request_org_invite,
# the FIRST-worlds landing view, and the OrganizerPositionInvite::Request approve
# callback. Centralizing the predicate prevents drift between "can the user see
# the Request-to-join button?", "can they actually request?", and "do they get a
# raffle entry on approval?".
RSpec.describe Event::Affiliation, type: :model do
  # The /first flow calls these via `current_user(allow_unverified: true)`,
  # so the predicates must work for users who haven't verified their email.
  let(:user) { create(:user, verified: false) }

  def give_user_first_affiliation(user, league:, team_number:)
    user.affiliations.create!(name: "first", league:, team_number:)
  end

  def give_event_first_affiliation(event, league:, team_number:)
    event.affiliations.create!(name: "first", league:, team_number:)
  end

  describe ".matching_first_event_for" do
    it "returns nil when the user has no FIRST affiliation" do
      event = create(:event)
      give_event_first_affiliation(event, league: "frc", team_number: "1234")

      expect(described_class.matching_first_event_for(user)).to be_nil
    end

    it "returns nil when no event affiliation matches the user's league + team_number" do
      give_user_first_affiliation(user, league: "frc", team_number: "1234")

      other_event = create(:event)
      give_event_first_affiliation(other_event, league: "frc", team_number: "9999")

      expect(described_class.matching_first_event_for(user)).to be_nil
    end

    it "returns the event whose FIRST affiliation matches league + team_number" do
      give_user_first_affiliation(user, league: "frc", team_number: "1234")

      matching_event = create(:event)
      give_event_first_affiliation(matching_event, league: "frc", team_number: "1234")

      expect(described_class.matching_first_event_for(user)).to eq(matching_event)
    end

    it "ignores Event affiliations whose league differs from the user's league" do
      give_user_first_affiliation(user, league: "frc", team_number: "1234")

      ftc_event = create(:event)
      give_event_first_affiliation(ftc_event, league: "ftc", team_number: "1234")

      expect(described_class.matching_first_event_for(user)).to be_nil
    end
  end

  describe ".first_affiliation_matches?" do
    it "is false when the user has no FIRST affiliation" do
      event = create(:event)
      give_event_first_affiliation(event, league: "frc", team_number: "1234")

      expect(described_class.first_affiliation_matches?(user, event)).to eq(false)
    end

    it "is false when the event has no matching FIRST affiliation" do
      give_user_first_affiliation(user, league: "frc", team_number: "1234")

      event = create(:event)
      give_event_first_affiliation(event, league: "frc", team_number: "9999")

      expect(described_class.first_affiliation_matches?(user, event)).to eq(false)
    end

    it "is true when user and event share league + team_number on a FIRST affiliation" do
      give_user_first_affiliation(user, league: "frc", team_number: "1234")
      event = create(:event)
      give_event_first_affiliation(event, league: "frc", team_number: "1234")

      expect(described_class.first_affiliation_matches?(user, event)).to eq(true)
    end

    it "is false when user is nil or event is nil" do
      expect(described_class.first_affiliation_matches?(nil, create(:event))).to eq(false)
      expect(described_class.first_affiliation_matches?(user, nil)).to eq(false)
    end
  end

  describe ".eligible_to_request_invite?" do
    let(:event) { create(:event) }

    before do
      give_user_first_affiliation(user, league: "frc", team_number: "1234")
      give_event_first_affiliation(event, league: "frc", team_number: "1234")
    end

    it "is true when the user is not yet a member and their affiliation matches" do
      expect(described_class.eligible_to_request_invite?(user, event)).to eq(true)
    end

    it "is false when the user is already an organizer of the event" do
      # OrganizerPosition requires a verified user (see
      # spec/models/unverified_users_no_organizer_position_spec.rb), so use
      # a verified user here. The eligibility predicate doesn't care about
      # verification status — only membership.
      member = create(:user, verified: true)
      member.affiliations.create!(name: "first", league: "frc", team_number: "1234")
      create(:organizer_position, user: member, event:)

      expect(described_class.eligible_to_request_invite?(member, event)).to eq(false)
    end

    it "is false when the affiliation does not match" do
      mismatched_event = create(:event)
      give_event_first_affiliation(mismatched_event, league: "frc", team_number: "9999")

      expect(described_class.eligible_to_request_invite?(user, mismatched_event)).to eq(false)
    end
  end
end
