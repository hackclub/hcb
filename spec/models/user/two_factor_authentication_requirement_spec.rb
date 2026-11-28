# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::TwoFactorAuthenticationRequirement, type: :model do
  let(:user) { create(:user) }
  let(:parent) { create(:event) }
  let(:event) { create(:event, parent:) }

  describe "#events_requiring_two_factor_authentication" do
    it "lists the requiring organizations at or above the user's positions" do
      create(:organizer_position, user:, event:)
      other = create(:event)
      require_two_factor_authentication!(parent)
      require_two_factor_authentication!(other)

      expect(user.events_requiring_two_factor_authentication).to contain_exactly(parent)
    end

    it "leaves out a sub-organization's requirement for a parent-only manager" do
      create(:organizer_position, user:, event: parent, role: :manager)
      require_two_factor_authentication!(event)

      expect(user.events_requiring_two_factor_authentication).to be_empty
    end
  end

  describe "#events_locked_out_for_two_factor_authentication" do
    it "is the user's organizations under an overdue requirement" do
      create(:organizer_position, user:, event:)
      untouched = create(:organizer_position, user:).event
      require_two_factor_authentication!(parent, at: 8.days.ago)

      expect(user.events_locked_out_for_two_factor_authentication).to contain_exactly(event)
      expect(user.events_locked_out_for_two_factor_authentication).not_to include(untouched)
    end

    it "is empty during the grace period and for users with two-factor authentication" do
      create(:organizer_position, user:, event:)
      require_two_factor_authentication!(parent, at: 2.days.ago)
      expect(user.events_locked_out_for_two_factor_authentication).to be_empty

      travel_to 8.days.from_now do
        expect(user.reload.events_locked_out_for_two_factor_authentication).to contain_exactly(event)
        expect(create(:user, :with_two_factor_authentication).events_locked_out_for_two_factor_authentication).to be_empty
      end
    end
  end
end
