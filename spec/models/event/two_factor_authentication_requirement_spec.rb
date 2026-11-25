# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::TwoFactorAuthenticationRequirement, type: :model do
  let(:event) { create(:event) }

  # Specs run Flipper on the in-memory adapter, which keeps no timestamps, so
  # the persisted gate row the app reads the enable time from is created here.
  def require_two_factor!(event, at: Time.current)
    Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)
    Flipper::Adapters::ActiveRecord::Gate.create!(feature_key: "require_two_factor_authentication_2026_11_24", key: "actors", value: event.flipper_id, created_at: at, updated_at: at)
  end

  describe ".requiring_two_factor_authentication" do
    it "lists only the organizations with the :require_two_factor_authentication_2026_11_24 enabled" do
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
      require_two_factor!(event, at: enabled_at)

      expect(event.two_factor_authentication_required_at).to eq(enabled_at)
      expect(event.two_factor_authentication_deadline).to eq(enabled_at + 7.days)
    end

    it "falls back to the boolean gate when the :require_two_factor_authentication_2026_11_24 is on for everyone" do
      enabled_at = Time.zone.parse("2026-11-24 12:00:00")
      Flipper.enable(:require_two_factor_authentication_2026_11_24)
      Flipper::Adapters::ActiveRecord::Gate.create!(feature_key: "require_two_factor_authentication_2026_11_24", key: "boolean", value: "true", created_at: enabled_at, updated_at: enabled_at)

      expect(event.two_factor_authentication_deadline).to eq(enabled_at + 7.days)
    end
  end

  describe "#two_factor_authentication_overdue_for?" do
    let(:user) { create(:user) }

    it "is false while the requirement is off" do
      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
    end

    it "is false during the grace period" do
      require_two_factor!(event, at: 6.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
    end

    it "is true once the grace period has passed" do
      require_two_factor!(event, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(true)
    end

    it "is false for users who use two-factor authentication" do
      user = create(:user, :with_two_factor_authentication)
      require_two_factor!(event, at: 8.days.ago)

      expect(event.two_factor_authentication_overdue_for?(user)).to eq(false)
    end
  end

  describe "#notify_two_factor_authentication_required" do
    it "emails every member" do
      members = create_list(:organizer_position, 2, event:).map(&:user)
      whodunnit = members.first

      expect {
        event.notify_two_factor_authentication_required(whodunnit:)
      }.to have_enqueued_mail(EventMailer, :two_factor_authentication_required).twice
    end
  end
end
