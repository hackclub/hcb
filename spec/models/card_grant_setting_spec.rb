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
end
