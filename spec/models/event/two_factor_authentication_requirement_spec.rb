# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::TwoFactorAuthenticationRequirement, type: :model do
  let(:event) { create(:event) }

  describe ".requiring_two_factor_authentication" do
    it "lists only the organizations with the flag enabled" do
      other = create(:event)
      Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)

      expect(Event.requiring_two_factor_authentication).to contain_exactly(event)
      expect(Event.requiring_two_factor_authentication).not_to include(other)
    end
  end

  describe "#two_factor_authentication_deadline" do
    it "is nil while the requirement is off" do
      expect(event.two_factor_authentication_required?).to eq(false)
      expect(event.two_factor_authentication_deadline).to be_nil
    end

    it "is the grace period after the :require_two_factor_authentication_2026_11_24 was enabled" do
      enabled_at = Time.zone.parse("2026-11-24 12:00:00")
      require_two_factor_authentication!(event, at: enabled_at)

      expect(event.two_factor_authentication_required_at).to eq(enabled_at)
      expect(event.two_factor_authentication_deadline).to eq(enabled_at + 7.days)
    end

    it "ignores a boolean gate, which would turn the requirement on everywhere at once" do
      enabled_at = Time.zone.parse("2026-11-24 12:00:00")
      Flipper.enable(:require_two_factor_authentication_2026_11_24)
      Flipper::Adapters::ActiveRecord::Gate.create!(feature_key: "require_two_factor_authentication_2026_11_24", key: "boolean", value: "true", created_at: enabled_at, updated_at: enabled_at)

      expect(event.two_factor_authentication_required?).to eq(false)
      expect(event.two_factor_authentication_deadline).to be_nil
      expect(Event.requiring_two_factor_authentication).to be_empty
    end

    it "is nil when the flag is on without a persisted gate row" do
      Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)

      expect(event.two_factor_authentication_required?).to eq(true)
      expect(event.two_factor_authentication_deadline).to be_nil
    end
  end

  describe "#two_factor_authentication_overdue_for?" do
    let(:user) { create(:organizer_position, event:).user }

    it "is false while the requirement is off" do
      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
    end

    it "is false during the grace period" do
      require_two_factor_authentication!(event, at: 6.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
    end

    it "is true once the grace period has passed" do
      require_two_factor_authentication!(event, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(true)
    end

    it "is false for users who use two-factor authentication" do
      user = create(:organizer_position, event:, user: create(:user, :with_two_factor_authentication)).user
      require_two_factor_authentication!(event, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
    end

    it "is false for users without a position at or below the organization" do
      outsider = create(:user)
      require_two_factor_authentication!(event, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(outsider)).to eq(false)
    end
  end

  describe "sub-organizations" do
    let(:parent) { create(:event) }
    let(:event) { create(:event, parent:) }
    let(:user) { create(:user) }

    it "covers members of sub-organizations when the parent requires it" do
      create(:organizer_position, user:, event:, role: :member)
      require_two_factor_authentication!(parent, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(true)
      expect(parent.two_factor_authentication_overdue_for?(user)).to eq(true)
    end

    it "covers the parent's managers in the sub-organizations beneath it" do
      create(:organizer_position, user:, event: parent, role: :manager)
      require_two_factor_authentication!(parent, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(true)
    end

    it "doesn't reach up to the parent's managers when only a sub-organization requires it" do
      create(:organizer_position, user:, event: parent, role: :manager)
      require_two_factor_authentication!(event, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
      expect(parent.two_factor_authentication_overdue_for?(user)).to eq(false)
    end
  end

  describe "#users_required_to_use_two_factor_authentication" do
    it "includes members of the organization and of its sub-organizations, but not of its parent" do
      parent = create(:event)
      event = create(:event, parent:)
      subevent = create(:event, parent: event)
      parent_manager = create(:organizer_position, event: parent, role: :manager).user
      member = create(:organizer_position, event:).user
      sub_member = create(:organizer_position, event: subevent).user

      expect(event.users_required_to_use_two_factor_authentication).to contain_exactly(member, sub_member)
      expect(event.users_required_to_use_two_factor_authentication).not_to include(parent_manager)
    end
  end

  describe "#notify_two_factor_authentication_required" do
    it "emails every member, including those of sub-organizations" do
      members = create_list(:organizer_position, 2, event:).map(&:user)
      create(:organizer_position, event: create(:event, parent: event))
      whodunnit = members.first

      expect {
        event.notify_two_factor_authentication_required(whodunnit:)
      }.to have_enqueued_mail(EventMailer, :two_factor_authentication_required).exactly(3).times
    end
  end
end
