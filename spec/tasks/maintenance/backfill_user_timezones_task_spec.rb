# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillUserTimezonesTask do
  describe "#collection" do
    it "includes a user with a reported session timezone and no preference" do
      user = create(:user)
      create(:user_session, user:, timezone: "America/Los_Angeles")

      expect(described_class.new.collection).to include(user)
    end

    it "excludes a user who has already chosen a timezone" do
      user = create(:user, timezone: "Eastern Time (US & Canada)")
      create(:user_session, user:, timezone: "America/Los_Angeles")

      expect(described_class.new.collection).not_to include(user)
    end

    it "excludes a user whose sessions reported nothing" do
      user = create(:user)
      create(:user_session, user:, timezone: nil)

      expect(described_class.new.collection).not_to include(user)
    end
  end

  describe "#process" do
    it "writes the inferred timezone under the name the picker offers" do
      user = create(:user)
      create(:user_session, user:, timezone: "America/Los_Angeles")

      described_class.new.process(user)

      expect(user.reload.timezone).to eq("Pacific Time (US & Canada)")
    end

    it "leaves the preference unset when nothing usable was reported" do
      user = create(:user)
      create(:user_session, user:, timezone: "Etc/Unknown")

      described_class.new.process(user)

      expect(user.reload.timezone).to be_nil
    end
  end
end
