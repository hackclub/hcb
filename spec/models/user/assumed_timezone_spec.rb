# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:user) { create(:user) }

  def session_with(timezone, last_seen_at:)
    create(:user_session, user:, timezone:, last_seen_at:)
  end

  describe "#assumed_timezone" do
    it "falls back to the default when the cardholder has no sessions" do
      expect(user.assumed_timezone).to eq(User::DEFAULT_TIMEZONE)
    end

    it "uses the timezone the browser reported" do
      session_with("Europe/London", last_seen_at: 1.day.ago)

      expect(user.assumed_timezone.name).to eq("Europe/London")
    end

    # A fortnight abroad should not repoint someone's timezone once they are home.
    it "prefers the most common timezone over the most recent one" do
      5.times { |i| session_with("America/Chicago", last_seen_at: (10 + i).days.ago) }
      session_with("Asia/Tokyo", last_seen_at: 1.day.ago)

      expect(user.assumed_timezone.name).to eq("America/Chicago")
    end

    it "breaks a tie toward the more recent timezone" do
      session_with("America/Chicago", last_seen_at: 10.days.ago)
      session_with("Europe/Berlin", last_seen_at: 1.day.ago)

      expect(user.assumed_timezone.name).to eq("Europe/Berlin")
    end

    # Some browsers report values ActiveSupport cannot resolve. Skipping to the
    # next candidate keeps a usable guess instead of dropping to the default.
    it "skips values ActiveSupport cannot resolve" do
      3.times { |i| session_with("UTC+480", last_seen_at: (10 + i).days.ago) }
      session_with("Europe/Lisbon", last_seen_at: 1.day.ago)

      expect(user.assumed_timezone.name).to eq("Europe/Lisbon")
    end

    it "falls back to the default when nothing resolves" do
      session_with("Etc/Unknown", last_seen_at: 1.day.ago)

      expect(user.assumed_timezone).to eq(User::DEFAULT_TIMEZONE)
    end

    it "ignores sessions with no reported timezone" do
      session_with(nil, last_seen_at: 1.day.ago)
      session_with("", last_seen_at: 2.days.ago)
      session_with("Europe/Madrid", last_seen_at: 3.days.ago)

      expect(user.assumed_timezone.name).to eq("Europe/Madrid")
    end
  end
end
