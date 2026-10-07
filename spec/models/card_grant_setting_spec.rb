# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantSetting, type: :model do
  describe "#slack_support?" do
    it "is true for a Slack URL" do
      expect(described_class.new(support_url: "https://hackclub.slack.com/archives/C123").slack_support?).to be true
    end

    it "is false for a non-Slack URL" do
      expect(described_class.new(support_url: "https://hackclub.com").slack_support?).to be false
    end

    it "is false for an invalid mailto URL instead of raising" do
      expect(described_class.new(support_url: "mailto:tagless.hackclub.com").slack_support?).to be false
    end
  end

  describe "support_url validation" do
    let(:setting) { create(:card_grant_setting) }

    ["https://hackclub.com/support", "http://hackclub.com", "mailto:orpheus@hackclub.com", nil, ""].each do |url|
      it "accepts #{url.inspect}" do
        setting.support_url = url
        expect(setting).to be_valid
      end
    end

    ["mailto:tagless.hackclub.com", "mailto:", "javascript:alert(1)", "data:text/html,<script>", "https://", "hackclub.com", "not a url"].each do |url|
      it "rejects #{url.inspect}" do
        setting.support_url = url
        expect(setting).not_to be_valid
        expect(setting.errors[:support_url]).to be_present
      end
    end

    it "does not block saving other fields on a legacy row with a bad URL" do
      setting.update_column(:support_url, "mailto:tagless.hackclub.com")
      expect(setting.update(support_message: "Reach out!")).to be true
    end
  end
end
