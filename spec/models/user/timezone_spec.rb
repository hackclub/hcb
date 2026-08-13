# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  let(:user) { create(:user) }

  def report_timezone(timezone, last_seen_at: Time.current, count: 1)
    count.times { create(:user_session, user:, timezone:, last_seen_at:) }
  end

  describe "#resolved_timezone" do
    it "prefers the configured timezone over anything the browser reported" do
      report_timezone("America/Los_Angeles", count: 5)
      user.update!(timezone: "Eastern Time (US & Canada)")

      expect(user.resolved_timezone.tzinfo.identifier).to eq("America/New_York")
    end

    it "falls back to the inferred timezone when nothing is configured" do
      report_timezone("America/Los_Angeles", count: 5)

      expect(user.timezone).to be_nil
      expect(user.resolved_timezone).to eq(ActiveSupport::TimeZone["America/Los_Angeles"])
    end

    it "falls back to the default when there is nothing to infer from" do
      expect(user.resolved_timezone).to eq(User::DEFAULT_TIMEZONE)
    end
  end

  describe "#inferred_timezone" do
    it "takes the most common value rather than the most recent one" do
      report_timezone("America/Chicago", last_seen_at: 1.month.ago, count: 4)
      report_timezone("Europe/Berlin", last_seen_at: 1.day.ago)

      expect(user.inferred_timezone).to eq(ActiveSupport::TimeZone["America/Chicago"])
    end

    it "breaks ties in favour of the more recently seen session" do
      report_timezone("America/Chicago", last_seen_at: 1.month.ago)
      report_timezone("Europe/Berlin", last_seen_at: 1.day.ago)

      expect(user.inferred_timezone).to eq(ActiveSupport::TimeZone["Europe/Berlin"])
    end

    it "skips values ActiveSupport cannot resolve in favour of the next candidate" do
      report_timezone("Etc/Unknown", count: 3)
      report_timezone("UTC+480", count: 2)
      report_timezone("Europe/Berlin")

      expect(user.inferred_timezone).to eq(ActiveSupport::TimeZone["Europe/Berlin"])
    end

    it "is nil when no session reported anything usable" do
      report_timezone("Etc/Unknown", count: 3)
      report_timezone(nil)
      report_timezone("")

      expect(user.inferred_timezone).to be_nil
    end
  end

  describe "the timezone attribute" do
    it "stores an IANA identifier under the name the picker offers" do
      user.update!(timezone: "America/New_York")

      expect(user.reload.timezone).to eq("Eastern Time (US & Canada)")
    end

    it "collapses a blank choice back to nil so the guess resumes" do
      user.update!(timezone: "Eastern Time (US & Canada)")
      user.update!(timezone: "")

      expect(user.reload.timezone).to be_nil
    end

    it "rejects a timezone that is not a real one" do
      user.timezone = "Middle Earth"

      expect(user).not_to be_valid
      expect(user.errors[:timezone]).to be_present
    end
  end

  describe ".selectable_timezone_name" do
    it "translates an IANA identifier into the equivalent option" do
      expect(described_class.selectable_timezone_name("Europe/Berlin")).to eq("Berlin")
    end

    it "is nil for a zone with no equivalent option" do
      expect(described_class.selectable_timezone_name("Etc/Unknown")).to be_nil
      expect(described_class.selectable_timezone_name(nil)).to be_nil
    end
  end
end
