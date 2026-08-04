# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillCardGrantSettingExpirationPreferenceTask, versioning: true do
  describe "#collection" do
    it "includes a setting left at 1 year" do
      setting = create(:card_grant_setting, expiration_preference: "1 year")

      expect(described_class.new.collection).to include(setting)
    end

    it "includes a setting whose other fields were edited" do
      setting = create(:card_grant_setting, expiration_preference: "1 year")
      setting.update!(invite_message: "It's pizza time!")

      expect(described_class.new.collection).to include(setting)
    end

    it "excludes a setting whose expiration preference was explicitly chosen" do
      setting = create(:card_grant_setting, expiration_preference: "6 months")
      setting.update!(expiration_preference: "1 year")

      expect(described_class.new.collection).not_to include(setting)
    end

    it "excludes settings at other expiration preferences" do
      settings = ["90 days", "6 months", "2 years"].map do |preference|
        create(:card_grant_setting, expiration_preference: preference)
      end

      expect(described_class.new.collection).not_to include(*settings)
    end
  end

  describe "#process" do
    it "moves the setting to 90 days" do
      setting = create(:card_grant_setting, expiration_preference: "1 year")

      described_class.new.process(setting)

      expect(setting.reload.expiration_preference).to eq("90 days")
    end
  end
end
